import json
import time

start_all()

# ── logs node: vector -> opentelemetry -> debug exporter ─────────────
logs.wait_for_unit("opentelemetry-collector.service")
logs.wait_for_unit("vector.service")

# generate a known log message
logs.succeed(
    "systemd-cat -t test-marker echo 'hello-from-integration-test'"
)

# The debug exporter (verbosity: normal) writes one line per log record to
# the collector's journal.  Wait for the marker to appear there.
logs.wait_until_succeeds(
    "journalctl -u opentelemetry-collector -b --no-pager | grep -q 'hello-from-integration-test'",
    timeout=120,
)

# read the debug output from the collector's journal
journal = logs.succeed("journalctl -u opentelemetry-collector -b --no-pager -o cat")


def parse_attrs(line):
    """Parse key=value attributes from a normal-verbosity debug log line."""
    attrs = {}
    for token in line.split():
        if "=" in token:
            key, _, value = token.partition("=")
            attrs[key] = value
    return attrs


# find the marker line and parse its key=value attributes
attrs = {}
for line in journal.splitlines():
    if "hello-from-integration-test" in line:
        attrs = parse_attrs(line)
        break

assert attrs, "test log message not found in collector journal"

# verify expected labels are present (unit comes from the vector remap
# transform, host_name from the journal's _HOSTNAME — matching what alloy's
# relabel rules produce; the collector's transform/service_name processor
# promotes unit to service.name on the resource, which the debug exporter
# reports on the resource line rather than the log-record line)
for label in [
    "unit",
    "host_name",
    "transport",
    "boot_id",
]:
    assert label in attrs, f"missing label '{label}' in {attrs.keys()}"

# the marker was emitted through systemd-cat -t test-marker; a non-empty
# unit attribute proves the journald -> remap -> OTLP path preserved the
# systemd unit of the caller
assert attrs["unit"], "unit attribute is empty"
print(f"Verified log record attributes: {attrs}")

print("Vector log pipeline passed!")

# ── metrics node: vector -> opentelemetry -> prometheus ──────────────
metrics.wait_for_unit("opentelemetry-collector.service")
metrics.wait_for_unit("vector.service")
metrics.wait_for_unit("prometheus.service")

machine_sleep = 5
metrics.sleep(machine_sleep)
for unit in [
    "opentelemetry-collector",
    "vector",
    "prometheus",
]:
    metrics.succeed(f"systemctl is-active {unit}.service")

# opentelemetry exposes the prometheus exporter
metrics.wait_for_open_port(8090)

# prometheus is up and healthy
metrics.wait_for_open_port(9090)
metrics.wait_until_succeeds(
    "curl -sf http://127.0.0.1:9090/-/healthy",
    timeout=60,
)

# the opentelemetry scrape target must be reported up
metrics.wait_until_succeeds(
    """curl -sf -G http://127.0.0.1:9090/api/v1/query \
        --data-urlencode 'query=up{job="opentelemetry"}' \
        | grep -q '"1"'""",
    timeout=120,
)
print("opentelemetry scrape target is up in prometheus")

# ── metrics flow end-to-end ───────────────────────────────────────────
# vector's host_metrics source feeds the otel collector; the
# metricstransform processor tags every series with host_name="test-host",
# so any collected metric reaching prometheus carries that label.  The
# vector `host` namespace prefixes metrics (e.g. host_cpu_seconds_total).
def host_series() -> int:
    out = metrics.succeed(
        "curl -sf -G http://127.0.0.1:9090/api/v1/query "
        '--data-urlencode \'query=count({host_name="test-host"})\''
    )
    data = json.loads(out)["data"]["result"]
    return int(data[0]["value"][1]) if data else 0


deadline = time.time() + 120
while time.time() < deadline and host_series() == 0:
    time.sleep(1)
assert host_series() > 0, "no host_name=test-host series found in prometheus"
print("Metrics pipeline verified: vector -> otel -> prometheus")
print("Vector metrics test passed!")
