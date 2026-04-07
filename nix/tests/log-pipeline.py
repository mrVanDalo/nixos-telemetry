import json


def find_test_log(raw):
    for line in raw.strip().splitlines():
        record = json.loads(line)
        assert "resourceLogs" in record, f"missing resourceLogs key: {record.keys()}"
        for resource_log in record["resourceLogs"]:
            for scope_log in resource_log.get("scopeLogs", []):
                for log_record in scope_log.get("logRecords", []):
                    body = log_record.get("body", {}).get("stringValue", "")
                    if "hello-from-integration-test" in body:
                        return log_record
    return None


start_all()

machine.wait_for_unit("opentelemetry-collector.service")
machine.wait_for_unit("alloy.service")

# wait for the loki receiver port to be ready
machine.wait_for_open_port(3500)

# generate a known log message
machine.succeed(
    "systemd-cat -t test-marker echo 'hello-from-integration-test'"
)

# wait for the message to propagate through alloy -> otel collector -> file
machine.wait_until_succeeds(
    "grep -q 'hello-from-integration-test' /var/lib/opentelemetry-collector/logs.json",
    timeout=120,
)

# read and parse the OTLP JSON output
raw = machine.succeed("cat /var/lib/opentelemetry-collector/logs.json")

log_record = find_test_log(raw)
assert log_record is not None, "test log message not found in any log record"

# collect attributes into a dict
attrs = {
    a["key"]: a["value"].get("stringValue", "")
    for a in log_record.get("attributes", [])
}

# verify expected labels are present
for label in [
    "unit",
    "instance_name",
    "transport",
    "boot_id",
    "priority",
    "priority_label",
]:
    assert label in attrs, f"missing label '{label}' in {attrs.keys()}"

# verify human-readable priority_label
valid_priorities = [
    "emergency",
    "alert",
    "critical",
    "error",
    "warning",
    "notice",
    "info",
    "debug",
]
assert attrs["priority_label"] in valid_priorities, (
    f"unexpected priority_label: {attrs['priority_label']}"
)

# verify hostname
assert attrs["instance_name"] == "test-host", (
    f"instance_name mismatch: {attrs['instance_name']}"
)

print(f"Verified log record attributes: {attrs}")

# verify that facility labels are present on logs that have SYSLOG_FACILITY
# (not all log sources set this field, but system daemons do)
has_facility = False
for line in raw.strip().splitlines():
    record = json.loads(line)
    for resource_log in record.get("resourceLogs", []):
        for scope_log in resource_log.get("scopeLogs", []):
            for log_record in scope_log.get("logRecords", []):
                attrs = {
                    a["key"]: a["value"].get("stringValue", "")
                    for a in log_record.get("attributes", [])
                }
                if "facility" in attrs:
                    has_facility = True
                    assert "facility_label" in attrs, (
                        "facility present but facility_label missing"
                    )
                    valid_facilities = [
                        "kern",
                        "user",
                        "mail",
                        "daemon",
                        "auth",
                        "syslog",
                        "lpr",
                        "news",
                        "uucp",
                        "clock",
                        "authpriv",
                        "ftp",
                        "cron",
                        "local0",
                        "local1",
                        "local2",
                        "local3",
                        "local4",
                        "local5",
                        "local6",
                        "local7",
                    ]
                    assert attrs["facility_label"] in valid_facilities, (
                        f"unexpected facility_label: {attrs['facility_label']}"
                    )
                    break

assert has_facility, "no log records with facility label found"
print("Log pipeline test passed!")
