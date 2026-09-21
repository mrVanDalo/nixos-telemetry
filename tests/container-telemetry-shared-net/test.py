start_all()

# ── host: collector + its own alloy on the DEFAULT UI port ────────────
host.wait_for_unit("opentelemetry-collector.service", timeout=180)
host.wait_for_open_port(3500, timeout=180) # loki receiver
host.wait_for_open_port(8088, timeout=180) # influxdb receiver
host.wait_for_unit("alloy.service", timeout=180)
host.wait_for_open_port(12345, timeout=180) # host alloy UI on the default port
print("host verified: collector listening, host alloy owns :12345")

# ── container boots: alloy active, UI moved off the host's port ───────
host.wait_until_succeeds("nixos-container status telemetry | grep -q up", timeout=180)
host.wait_until_succeeds(
    "nixos-container run telemetry -- systemctl is-active alloy.service",
    timeout=180,
)
print("container agents verified: alloy running inside the container")

# the container's alloy UI must listen on the OFFSET port :12346, not
# clash with the host's :12345 — the whole point of the recommendation.
host.wait_until_succeeds(
    "nixos-container run telemetry -- ss -tlnp | grep -q ':12346'",
    timeout=180,
)
print("container alloy UI verified: listening on offset port :12346")

# ── logs: container journal -> alloy -> host collector (shared netns) ─
host.succeed("nixos-container run telemetry -- systemd-cat -t test-marker echo 'hello-from-container-test'")

# The debug exporter on the host writes one line per log record to the
# host collector's journal — the marker must have traversed
# container -> host over OTLP via the shared loopback.
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
# rule, the container runs no collector), so the receiving HOST collector
# fills the unset host.name with its own hostname (override=false) —
# identity still travels via container_name.
assert "host.name=host" in journal, (
    "receiving host collector did not stamp host.name=host onto container logs"
)
print("container log forwarding verified: telemetry -> host (container_name=telemetry, is_container=true, host.name=host)")

# ── metrics pipeline infrastructure (wired, scraped) ──────────────────
host.wait_for_unit("prometheus.service", timeout=180)
host.wait_for_open_port(9090, timeout=180)
host.wait_until_succeeds(
    """curl -sf -G http://127.0.0.1:9090/api/v1/query \
        --data-urlencode 'query=up{job="opentelemetry"}' \
        | grep -q '"value":\\[.*,"1"\\]'""",
    timeout=120,
)
print("metrics pipeline infrastructure: collector -> prometheus exporter -> prometheus scrape (up=1)")

# ── metrics: container telegraf -> host influxdb/telegraf -> host ─────
# proof: the host runs no telegraf itself, so any series carrying
# container_name="telemetry" originates from the container's telegraf
# (global_tags stamps container_name/is_container).
host.wait_until_succeeds(
    """curl -sf -G http://127.0.0.1:9090/api/v1/query \
        --data-urlencode 'query=count({container_name="telemetry", is_container="true"})' \
        | grep -qv '"result":\\[\\]'""",
    timeout=120,
)
print("container metric forwarding verified: telegraf -> host prometheus (container_name=telemetry, is_container=true)")
