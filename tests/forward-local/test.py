start_all()

# ── services come up ──────────────────────────────────────────────────
source.wait_for_unit("opentelemetry-collector.service")
source.wait_for_unit("alloy.service")
source.wait_for_unit("telegraf.service")
source.wait_for_unit("loki.service")
source.wait_for_unit("grafana.service")
source.wait_for_unit("prometheus.service")
target.wait_for_unit("opentelemetry-collector.service")
target.wait_for_unit("prometheus.service")

# the remote target must listen for OTLP before the source sends
target.wait_for_open_port(4317)

# ── logs: source -> target (remote forwarding) ────────────────────────
source.succeed("systemd-cat -t test-marker echo 'hello-from-forward-local-test'")

# The debug exporter on the remote target writes one line per log record
# to its collector journal — the marker must have traversed source -> target.
target.wait_until_succeeds(
    "journalctl -u opentelemetry-collector -b --no-pager | grep -q 'hello-from-forward-local-test'",
    timeout=240,
)
journal = target.succeed("journalctl -u opentelemetry-collector -b --no-pager -o cat")
assert "host.name=source" in journal, (
    "log from source (host.name=source) not found in target's collector journal"
)
print("Remote log forwarding verified: source -> target (host.name=source)")

# ── metrics: source -> target (remote forwarding) ─────────────────────
# `target` has no local metric source, so every metric reaching it must
# have arrived over OTLP from `source`. The metricstransform processor tags
# metrics host_name="source"; prometheus-internal metrics (e.g. `up`) lack it.
target.wait_for_open_port(9090)
target.wait_until_succeeds(
    """curl -sf -G http://127.0.0.1:9090/api/v1/query \
        --data-urlencode 'query=count({host_name="source"})' \
        | grep -qv '"result":\\[\\]'""",
    timeout=240,
)
print("Remote metric forwarding verified: source -> target (host_name=source)")

# ── local loki on source sees the logs ────────────────────────────────
# The collector's otlphttp/loki exporter pushes logs to the local loki.
# resourcedetection sets host.name=source, loki promotes it to host_name.
source.wait_until_succeeds("curl -sf http://127.0.0.1:3100/ready")
source.wait_until_succeeds(
    """curl -sf -G http://127.0.0.1:3100/loki/api/v1/query_range \
        --data-urlencode 'query={host_name="source"} |= "hello-from-forward-local-test"' \
        --data-urlencode 'start='$(($(date +%s) - 3600))'000000000' \
        --data-urlencode 'end='$(($(date +%s) + 300))'000000000' \
        | grep -q 'hello-from-forward-local-test'""",
    timeout=120,
)
print("Local loki verified: collector -> loki (host_name=source)")

# ── local prometheus on source sees the metrics ───────────────────────
# The collector's prometheus exporter (port 8090) is scraped by the local
# prometheus. The metricstransform processor tags host_name="source".
source.wait_for_open_port(8090)
source.wait_for_open_port(9090)
source.wait_until_succeeds(
    """curl -sf -G http://127.0.0.1:9090/api/v1/query \
        --data-urlencode 'query=count({host_name="source"})' \
        | grep -qv '"result":\\[\\]'""",
    timeout=120,
)
print("Local prometheus verified: collector -> prometheus (host_name=source)")

# ── grafana has both datasources provisioned ──────────────────────────
source.wait_for_open_port(3000)
datasources = source.succeed("curl -sf -u admin:admin http://127.0.0.1:3000/api/datasources")
assert '"OTLP Loki"' in datasources, "OTLP Loki datasource not provisioned in Grafana"
assert '"Prometheus"' in datasources, "Prometheus datasource not provisioned in Grafana"
print("Grafana datasources verified: OTLP Loki + Prometheus present")

# ── collector isn't dropping data ─────────────────────────────────────
journal = source.succeed("journalctl -u opentelemetry-collector --no-pager -n 80")
assert "Dropping data" not in journal, (
    "OTel collector on source is dropping data — pipeline is broken"
)
print("No data dropped in source's OTel collector logs")
print("forward-local test passed!")