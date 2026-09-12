start_all()

# ── host collector up and listening ───────────────────────────────────
host.wait_for_unit("opentelemetry-collector.service")
host.wait_for_open_port(4317)

# ── container boots with the module's convenience defaults ────────────
host.wait_until_succeeds("nixos-container status telemetry | grep -q up", timeout=120)
host.wait_until_succeeds(
    "nixos-container run telemetry -- systemctl is-active opentelemetry-collector.service alloy.service",
    timeout=180,
)
print("container module defaults verified: collector + alloy running inside the container")

# journald cap set by the container module
host.succeed("nixos-container run telemetry -- grep -q 'SystemMaxUse=1G' /etc/systemd/journald.conf")
print("container module default verified: journald SystemMaxUse=1G")

# container shares the host network namespace: the exporter must be
# wired to localhost, not a bridge address
host.succeed("nixos-container run telemetry -- opentelemetry-show-config | grep -q 'localhost:4317'")

# The debug exporter on the host writes one line per log record to the
# host collector's journal — the marker must have traversed
# container -> localhost:4317 -> host over OTLP.
host.wait_until_succeeds(
    "journalctl -u opentelemetry-collector -b --no-pager | grep -q 'hello-from-container-hostnet-test'",
    timeout=240,
)
journal = host.succeed("journalctl -u opentelemetry-collector -b --no-pager -o cat")
assert "host.name=telemetry" in journal, (
    "log from container (host.name=telemetry) not found in host's collector journal"
)
print("container log forwarding verified: telemetry -> localhost:4317 -> host (host.name=telemetry)")

# ── metrics: telegraf in container -> host prometheus ─────────────────
host.succeed("nixos-container run telemetry -- systemctl is-active telegraf.service")
host.wait_for_open_port(9090)
# The host collector has no local metric source, so every metric with
# host_name="telemetry" must have arrived over OTLP from the container.
host.wait_until_succeeds(
    """curl -sf -G http://127.0.0.1:9090/api/v1/query \\
        --data-urlencode 'query=count({host_name="telemetry"})' \\
        | grep -qv '"result":\\[\\]'""",
    timeout=240,
)
print("container metric forwarding verified: telemetry -> localhost:4317 -> host (host_name=telemetry)")

# ── host collector isn't dropping data ────────────────────────────────
journal = host.succeed("journalctl -u opentelemetry-collector --no-pager -n 80")
assert "Dropping data" not in journal, (
    "OTel collector on host is dropping data — pipeline is broken"
)
print("container-telemetry-hostnet test passed!")