start_all()

# ── services come up ──────────────────────────────────────────────────
source.wait_for_unit("opentelemetry-collector.service")
source.wait_for_unit("alloy.service")
source.wait_for_unit("telegraf.service")
proxy.wait_for_unit("opentelemetry-collector.service")
sink.wait_for_unit("opentelemetry-collector.service")
sink.wait_for_unit("prometheus.service")

# relays/sink must listen before the upstream sends
proxy.wait_for_open_port(4317)
sink.wait_for_open_port(4317)

# ── logs: source -> proxy -> sink ─────────────────────────────────────
source.succeed("systemd-cat -t test-marker echo 'hello-from-forward-chain-test'")

# The debug exporter (verbosity: normal) writes one line per log record to
# the collector's journal.  Wait for the marker to appear there — it must
# have traversed source -> proxy -> sink.
sink.wait_until_succeeds(
    "journalctl -u opentelemetry-collector -b --no-pager | grep -q 'hello-from-forward-chain-test'",
    timeout=240,
)

# Verify the log originated from source: the ResourceLog line in the debug
# output carries host.name=source as a resource attribute.
journal = sink.succeed("journalctl -u opentelemetry-collector -b --no-pager -o cat")
assert "host.name=source" in journal, (
    "log from source (host.name=source) not found in sink's collector journal after relay through proxy"
)
print("Log forwarded source -> proxy -> sink verified (host.name=source)")

# ── metrics: source -> proxy -> sink ──────────────────────────────────
# only `source` has a metric source (telegraf); proxy is a pure relay and
# sink has none, so any metric on sink must have traversed the full chain.
# The metricstransform processor on `source` tags metrics host_name="source";
# that label survives both hops (add_label does not overwrite an existing
# label), so we can confirm the source directly. prometheus-internal metrics
# (e.g. `up`) lack the label.
sink.wait_for_open_port(9090)
sink.wait_until_succeeds(
    """curl -sf -G http://127.0.0.1:9090/api/v1/query \
        --data-urlencode 'query=count({host_name="source"})' \
        | grep -qv '"result":\\[\\]'""",
    timeout=240,
)
print("Metrics forwarded source -> proxy -> sink verified (host_name=source)")
print("forward-chain test passed!")