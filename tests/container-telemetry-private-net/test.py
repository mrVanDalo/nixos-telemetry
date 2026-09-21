start_all()

# ── host collector up and listening ───────────────────────────────────
host.wait_for_unit("opentelemetry-collector.service", timeout=180)
host.wait_for_open_port(4317, timeout=180)

# ── container boots with the module's convenience defaults ────────────
host.wait_until_succeeds("nixos-container status telemetry | grep -q up", timeout=180)
host.wait_until_succeeds(
    "nixos-container run telemetry -- systemctl is-active opentelemetry-collector.service alloy.service",
    timeout=180,
)
print("container module defaults verified: collector + alloy running inside the container")

# ── logs: container journal -> alloy -> container collector -> host ───
host.succeed("nixos-container run telemetry -- systemd-cat -t test-marker echo 'hello-from-container-test'")

# The debug exporter on the host writes one line per log record to the
# host collector's journal — the marker must have traversed
# container -> host over OTLP.
host.wait_until_succeeds(
    "journalctl -u opentelemetry-collector -b --no-pager | grep -q 'hello-from-container-test'",
    timeout=180,
)
journal = host.succeed("journalctl -u opentelemetry-collector -b --no-pager -o cat")
assert "container_name=telemetry" in journal, (
    "container_name label from alloy not present in host's collector journal"
)
assert "is_container=true" in journal, (
    "is_container label from alloy not present in host's collector journal"
)
# the container stamps no hostname of its own (alloy sets no host_name
# rule, the container's collector runs no resourcedetection), so the
# receiving HOST collector fills the unset host.name with its own
# hostname (override=false) — identity still travels via container_name.
assert "host.name=host" in journal, (
    "receiving host collector did not stamp host.name=host onto container logs"
)
print("container log forwarding verified: telemetry -> host (container_name=telemetry, is_container=true, host.name=host)")

# ── metrics: container telegraf -> container collector -> host ───────
host.wait_for_unit("prometheus.service", timeout=180)
host.wait_until_succeeds(
    """curl -sf -G http://127.0.0.1:9090/api/v1/query \
        --data-urlencode 'query=count({container_name="telemetry", is_container="true"})' \
        | grep -qv '"result":\\[\\]'""",
    timeout=120,
)
print("container metric forwarding verified: telegraf -> host prometheus (container_name=telemetry, is_container=true)")
