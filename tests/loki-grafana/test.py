start_all()

# ── opentelemetry-collector should start and stay running ──────────────
machine.wait_for_unit("opentelemetry-collector.service")
machine.succeed("systemctl is-active opentelemetry-collector.service")
# give it a few seconds, then confirm it didn't crash (no metrics pipeline should exist)
machine.sleep(5)
machine.succeed("systemctl is-active opentelemetry-collector.service")

# ── alloy should be running (default: logs.enable = true) ─────────────
machine.wait_for_unit("alloy.service")
machine.succeed("systemctl is-active alloy.service")

# ── loki should be running and listening on port 3100 ─────────────────
machine.wait_for_unit("loki.service")
machine.succeed("systemctl is-active loki.service")
machine.wait_for_open_port(3100)

# loki should respond to /ready
machine.wait_until_succeeds("curl -sf http://127.0.0.1:3100/ready")

# ── grafana should be running and listening on port 3000 ───────────────
machine.wait_for_unit("grafana.service")
machine.succeed("systemctl is-active grafana.service")
machine.wait_for_open_port(3000)

# grafana should respond with a login page
machine.succeed("curl -sf http://127.0.0.1:3000/api/health | grep -q 'ok'")

# ── grafana should have provisioned datasources ───────────────────────
# loki datasource should be present (prometheus should NOT, it's not enabled)
datasources = machine.succeed("curl -sf http://127.0.0.1:3000/api/datasources")
assert '"Loki"' in datasources, "Loki datasource not provisioned in Grafana"
assert '"Prometheus"' not in datasources, "Prometheus datasource should not be provisioned"
print("Grafana datasources verified: Loki present, Prometheus absent")

# ── logs should flow through alloy → otel → loki ──────────────────────
# generate a known log message
machine.succeed("systemd-cat -t test-marker echo 'hello-from-loki-grafana-test'")

# In the OTLP pipeline, alloy's labels (job, instance_name, unit, ...) become
# log-level attributes (structured metadata in Loki), NOT stream labels. Stream
# labels come only from resource attributes:
#   - host.name (from the resourcedetection/system processor)  -> host_name
#   - service.name (copied from the systemd `unit` attribute by the
#     transform/service_name processor, then split per service by
#     groupbyattrs)                                                -> service_name
# See https://grafana.com/docs/loki/latest/get-started/labels/
#
# query_range (not the instant /query endpoint) is used: the VM clock can lag
# the journal timestamps, so an instant query at "now" may miss freshly
# ingested logs, while a range query with a small future window catches them.
machine.wait_until_succeeds(
    """curl -sf -G http://127.0.0.1:3100/loki/api/v1/query_range \
        --data-urlencode 'query={host_name="test-host"} |= "hello-from-loki-grafana-test"' \
        --data-urlencode 'start='$(($(date +%s) - 3600))'000000000' \
        --data-urlencode 'end='$(($(date +%s) + 300))'000000000' \
        | grep -q 'hello-from-loki-grafana-test'""",
    timeout=90,
)
print("Log pipeline verified (host_name filter): journal → alloy → otel → loki")

# ── service_name must be a meaningful, filterable label ───────────────
# Each systemd unit becomes its own Loki stream labeled service_name=<unit>
# (e.g. "grafana"), instead of everything collapsing to Loki's
# "unknown_service" fallback.
machine.wait_until_succeeds(
    """curl -sf http://127.0.0.1:3100/loki/api/v1/label/service_name/values \
        | grep -q '"grafana"'""",
    timeout=60,
)
service_names = machine.succeed(
    "curl -sf http://127.0.0.1:3100/loki/api/v1/label/service_name/values"
)
print(f"service_name label values: {service_names.strip()}")

# filtering by service_name must return that service's own logs
machine.wait_until_succeeds(
    """curl -sf -G http://127.0.0.1:3100/loki/api/v1/query_range \
        --data-urlencode 'query={service_name="grafana"}' \
        --data-urlencode 'start='$(($(date +%s) - 3600))'000000000' \
        --data-urlencode 'end='$(($(date +%s) + 300))'000000000' \
        --data-urlencode 'limit=5' \
        | grep -qv '"result":\\[\\]'""",
    timeout=60,
)
print("service_name filter verified: {service_name=\"grafana\"} returns logs")

# ── verify the collector isn't dropping data (retries are fine) ────────
journal = machine.succeed("journalctl -u opentelemetry-collector --no-pager -n 80")
assert "Dropping data" not in journal, (
    "OTel collector is dropping data — pipeline is broken"
)
print("No data dropped in OTel collector logs")
print("Loki-Grafana test passed!")