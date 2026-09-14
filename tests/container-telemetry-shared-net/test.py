start_all()

# ── host collector up with auto-wired receivers ───────────────────────
host.wait_for_unit("opentelemetry-collector.service")
config = host.succeed("opentelemetry-show-config")
# the config is serialized YAML: `receivers:` block with nested `loki:` /
# `influxdb:` entries — assert on the endpoint values, which are unique to
# the auto-wired receivers
assert "127.0.0.1:3500" in config, "loki receiver not in collector config — auto-wire failed"
assert "127.0.0.1:8088" in config, "influxdb receiver not in collector config — auto-wire failed"
print("host collector auto-wire verified: receivers.loki + receivers.influxdb present")

# ── container boots: alloy + telegraf active, collector inactive ──────
host.wait_until_succeeds("nixos-container status telemetry | grep -q up", timeout=120)
host.succeed("nixos-container run telemetry -- systemctl is-active alloy.service")
host.succeed("nixos-container run telemetry -- systemctl is-active telegraf.service")
# the collector must be forced off — mkForce false means it cannot start
result = host.succeed(
    "nixos-container run telemetry -- sh -c 'systemctl is-active opentelemetry-collector.service 2>&1 || true'"
).strip()
assert "inactive" in result or "could not be found" in result, (
    f"collector should be inactive in shared-net container, got: {result}"
)
print("container agents verified: alloy + telegraf active, collector inactive (mkForce)")

# journald cap set by the container module
host.succeed("nixos-container run telemetry -- grep -q 'SystemMaxUse=1G' /etc/systemd/journald.conf")
print("container module default verified: journald SystemMaxUse=1G")

# ── metrics identity: telegraf stamps host_name ───────────────────────
host.wait_for_open_port(9090)
# the host collector has no local metric source, so every metric with
# host_name="telemetry" was pushed by the container's telegraf over the
# shared loopback, stamped by global_tags.host_name
try:
    host.wait_until_succeeds(
        """curl -sf -G http://127.0.0.1:9090/api/v1/query \\
            --data-urlencode 'query=count({host_name="telemetry"})' \\
            | grep -qv '"result":\\[\\]'""",
        timeout=240,
    )
except Exception:
    webq = host.execute("curl -s -G http://127.0.0.1:9090/api/v1/query --data-urlencode 'query=count({host_name=\"telemetry\"})'")[1]
    up = host.execute("curl -s -G http://127.0.0.1:9090/api/v1/query --data-urlencode 'query=up'")[1]
    exporter = host.execute("curl -s http://127.0.0.1:8090/metrics | grep -c 'otelcol' ; curl -s http://127.0.0.1:8090/metrics | head -3")[1]
    recv = host.execute("curl -s -o /dev/null -w '%{http_code}' -X POST 'http://127.0.0.1:8088/api/v2/write?org=o&bucket=b' --data-binary 'test,host=x v=1'")[1]
    cfgpipe = host.execute("opentelemetry-show-config | sed -n '/^service:/,$p'")[1]
    metrics = host.execute("curl -s -w 'HTTPCODE:%{http_code}' http://127.0.0.1:8090/metrics | head -c 300")[1]
    colproc = host.execute("journalctl -u opentelemetry-collector -b --no-pager -o cat | grep -viE 'deprecated|resource' | tail -n 6")[1]
    compact = lambda s: s.replace("\n", "|")[:400]
    raise AssertionError(
        f"METRICDIAG6 cfgpipe={compact(cfgpipe)} metrics={compact(metrics)} colproc={compact(colproc)}"
    )
print("container metric identity verified: count({host_name=\"telemetry\"}) non-empty")
# ── log identity: alloy stamps host_name from journal ─────────────────
# alloy ships the container journal to the host collector, which exports
# to loki; loki promotes host.name to the host_name label
host.succeed("nixos-container run telemetry -- systemd-cat -t testmarker echo 'hello-from-container-hostnet-test'")
host.wait_until_succeeds("curl -sf http://127.0.0.1:3100/ready", timeout=120)
host.wait_until_succeeds(
    """curl -sf -G http://127.0.0.1:3100/loki/api/v1/query_range \\
        --data-urlencode 'query={host_name="telemetry"} |= "hello-from-container-hostnet-test"' \\
        --data-urlencode 'start='$(($(date +%s) - 3600))'000000000' \\
        --data-urlencode 'end='$(($(date +%s) + 300))'000000000' \\
        | grep -qv '"result":\\[\\]'""",
    timeout=240,
)
print("container log identity verified: host_name=telemetry on container logs in loki")

# ── host collector isn't dropping data ────────────────────────────────
journal = host.succeed("journalctl -u opentelemetry-collector --no-pager -n 80")

assert "Dropping data" not in journal, (
    "OTel collector on host is dropping data — pipeline is broken"
)
print("container-telemetry-hostnet test passed!")
