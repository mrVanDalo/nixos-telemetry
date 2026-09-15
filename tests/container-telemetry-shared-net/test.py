start_all()

# ── host collector up and listening ───────────────────────────────────
host.wait_for_unit("opentelemetry-collector.service", timeout=20)
# shared-net topology: the host opens the agent-facing receivers on the
# shared loopback (auto-wire); the OTLP receiver on 4317 is NOT wired
# because no receiver.endpoint is set on the host.
host.wait_for_open_port(3500, timeout=20) # loki receiver
host.wait_for_open_port(8088, timeout=20) # influxdb receiver

# ── container boots: alloy active, collector forced off ───────────────
host.wait_until_succeeds("nixos-container status telemetry | grep -q up", timeout=20)
host.wait_until_succeeds(
    "nixos-container run telemetry -- systemctl is-active alloy.service",
    timeout=20,
)
print("container agents verified: alloy running inside the container")

# journald cap set by the container module
host.succeed("nixos-container run telemetry -- grep -q 'SystemMaxUse=1G' /etc/systemd/journald.conf")
print("container module default verified: journald SystemMaxUse=1G")

# ── logs: container journal -> alloy -> host collector (shared netns) ─
host.succeed("nixos-container run telemetry -- systemd-cat -t test-marker echo 'hello-from-container-test'")

# The debug exporter on the host writes one line per log record to the
# host collector's journal — the marker must have traversed
# container -> host over OTLP via the shared loopback.
host.wait_until_succeeds(
    "journalctl -u opentelemetry-collector -b --no-pager | grep -q 'hello-from-container-test'",
    timeout=20,
)
journal = host.succeed("journalctl -u opentelemetry-collector -b --no-pager -o cat")
assert "host.name=telemetry" in journal, (
    "log from container (host.name=telemetry) not found in host's collector journal"
)
assert "container_name=telemetry" in journal, (
    "container_name label from alloy not present in host's collector journal"
)
assert "is_container=true" in journal, (
    "is_container label from alloy not present in host's collector journal"
)
print("container log forwarding verified: telemetry -> host (host.name=telemetry, container_name=telemetry, is_container=true)")

# metrics assertions intentionally omitted (covered by tests/metrics)

