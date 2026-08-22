start_all()

# ── services come up ──────────────────────────────────────────────────
source.wait_for_unit("opentelemetry-collector.service")
source.wait_for_unit("alloy.service")
source.wait_for_unit("telegraf.service")
target1.wait_for_unit("opentelemetry-collector.service")
target1.wait_for_unit("prometheus.service")
target2.wait_for_unit("opentelemetry-collector.service")
target2.wait_for_unit("prometheus.service")

# both targets must listen before the source sends
target1.wait_for_open_port(4317)
target2.wait_for_open_port(4317)

# ── logs: source -> target-1 AND source -> target-2 ────────────────────
source.succeed("systemd-cat -t test-marker echo 'hello-from-fanout-test'")

# The debug exporter (verbosity: normal) writes one line per log record to
# the collector's journal.  Wait for the marker to appear on BOTH targets.
for target in (target1, target2):
    target.wait_until_succeeds(
        "journalctl -u opentelemetry-collector -b --no-pager | grep -q 'hello-from-fanout-test'",
        timeout=240,
    )

# Verify the log originated from source on both targets: the ResourceLog
# line in the debug output carries host.name=source as a resource attribute.
for name, target in (("target-1", target1), ("target-2", target2)):
    journal = target.succeed("journalctl -u opentelemetry-collector -b --no-pager -o cat")
    assert "host.name=source" in journal, (
        f"log from source (host.name=source) not found in {name}'s collector journal"
    )
print("Log fan-out verified: source -> target-1 AND source -> target-2 (host.name=source)")

# ── metrics: source -> target-1 AND source -> target-2 ──────────────────
# Neither target has a local metric source (no telegraf/netdata), so every
# metric reaching them must have arrived over OTLP from `source`. The
# metricstransform processor on `source` tags metrics host_name="source";
# that label survives the hop, so we can confirm the source directly.
# prometheus-internal metrics (e.g. `up`) lack the label.
for name, target in (("target-1", target1), ("target-2", target2)):
    target.wait_for_open_port(9090)
    target.wait_until_succeeds(
        """curl -sf -G http://127.0.0.1:9090/api/v1/query \
            --data-urlencode 'query=count({host_name="source"})' \
            | grep -qv '"result":\\[\\]'""",
        timeout=240,
    )
    print(f"Metrics fan-out verified: source -> {name} (host_name=source)")

print("forward-fanout test passed!")