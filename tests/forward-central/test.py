start_all()

# ── services come up ──────────────────────────────────────────────────
source.wait_for_unit("opentelemetry-collector.service")
source.wait_for_unit("alloy.service")
source.wait_for_unit("telegraf.service")
sink.wait_for_unit("opentelemetry-collector.service")
sink.wait_for_unit("prometheus.service")

# the sink must be listening for OTLP before the source sends
sink.wait_for_open_port(4317)

# ── logs: source -> sink ──────────────────────────────────────────────
source.succeed("systemd-cat -t test-marker echo 'hello-from-forward-central-test'")

# The debug exporter (verbosity: normal) writes one line per log record to
# the collector's journal.  Wait for the marker to appear there — it must
# have traversed source -> sink.
sink.wait_until_succeeds(
    "journalctl -u opentelemetry-collector -b --no-pager | grep -q 'hello-from-forward-central-test'",
    timeout=180,
)

# Verify the log originated from source: the ResourceLog line in the debug
# output carries host.name=source as a resource attribute.
journal = sink.succeed("journalctl -u opentelemetry-collector -b --no-pager -o cat")
assert "host.name=source" in journal, (
    "log from source (host.name=source) not found in sink's collector journal"
)
print("Log forwarded source -> sink verified (host.name=source)")

# ── metrics: source -> sink ───────────────────────────────────────────
# `sink` has no local metric source (no telegraf/netdata), so every metric
# reaching it must have arrived over OTLP from `source`. The metricstransform
# processor on `source` tags metrics host_name="source"; that label survives
# the hop (add_label does not overwrite an existing label), so we can confirm
# the source directly. prometheus-internal metrics (e.g. `up`) lack the label.
sink.wait_for_open_port(9090)
sink.wait_until_succeeds(
    """curl -sf -G http://127.0.0.1:9090/api/v1/query \
        --data-urlencode 'query=count({host_name="source"})' \
        | grep -qv '"result":\\[\\]'""",
    timeout=180,
)
print("Metrics forwarded source -> sink verified (host_name=source)")
print("forward-central test passed!")