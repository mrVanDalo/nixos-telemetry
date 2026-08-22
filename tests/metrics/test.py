start_all()

# ── core services come up and stay up ─────────────────────────────────
machine.wait_for_unit("opentelemetry-collector.service")
machine.wait_for_unit("telegraf.service")
machine.wait_for_unit("netdata.service")
machine.wait_for_unit("prometheus.service")

# give them a moment, then confirm none crashed
machine.sleep(5)
for unit in [
    "opentelemetry-collector",
    "telegraf",
    "netdata",
    "prometheus",
]:
    machine.succeed(f"systemctl is-active {unit}.service")

# ── netdata serves metrics on its port ────────────────────────────────
machine.wait_for_open_port(19999)
# write to a file first: the allmetrics response is large, and piping into
# `grep -q` closes the pipe early (SIGPIPE -> curl exit 23 under pipefail).
machine.succeed(
    "curl -sf 'http://127.0.0.1:19999/api/v1/allmetrics?format=prometheus' -o /tmp/netdata.metrics"
)
machine.succeed("grep -q 'netdata' /tmp/netdata.metrics")

# ── opentelemetry exposes the prometheus exporter ─────────────────────
machine.wait_for_open_port(8090)

# ── prometheus is up and healthy ──────────────────────────────────────
machine.wait_for_open_port(9090)
machine.wait_until_succeeds(
    "curl -sf http://127.0.0.1:9090/-/healthy",
    timeout=60,
)

# the opentelemetry scrape target must be reported up
machine.wait_until_succeeds(
    """curl -sf -G http://127.0.0.1:9090/api/v1/query \
        --data-urlencode 'query=up{job="opentelemetry"}' \
        | grep -q '"1"'""",
    timeout=120,
)
print("opentelemetry scrape target is up in prometheus")

# ── metrics flow end-to-end ───────────────────────────────────────────
# telegraf and netdata feed the otel collector; the metricstransform
# processor tags every series with host_name="test-host", so any collected
# metric reaching prometheus carries that label.
machine.wait_until_succeeds(
    """curl -sf -G http://127.0.0.1:9090/api/v1/query \
        --data-urlencode 'query=count({host_name="test-host"})' \
        | grep -qv '"result":\\[\\]'""",
    timeout=120,
)
print("Metrics pipeline verified: telegraf/netdata -> otel -> prometheus")
print("Metrics test passed!")