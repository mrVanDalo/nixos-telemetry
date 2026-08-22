start_all()

machine.wait_for_unit("opentelemetry-collector.service")
machine.wait_for_unit("alloy.service")

# wait for the loki receiver port to be ready
machine.wait_for_open_port(3500)

# generate a known log message
machine.succeed(
    "systemd-cat -t test-marker echo 'hello-from-integration-test'"
)

# The debug exporter (verbosity: normal) writes one line per log record to
# the collector's journal.  Wait for the marker to appear there.
machine.wait_until_succeeds(
    "journalctl -u opentelemetry-collector -b --no-pager | grep -q 'hello-from-integration-test'",
    timeout=120,
)

# read the debug output from the collector's journal
journal = machine.succeed("journalctl -u opentelemetry-collector -b --no-pager -o cat")


def parse_attrs(line):
    """Parse key=value attributes from a normal-verbosity debug log line."""
    attrs = {}
    for token in line.split():
        if "=" in token:
            key, _, value = token.partition("=")
            attrs[key] = value
    return attrs


# find the marker line and parse its key=value attributes
attrs = {}
for line in journal.splitlines():
    if "hello-from-integration-test" in line:
        attrs = parse_attrs(line)
        break

assert attrs, "test log message not found in collector journal"

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
    "emerg",
    "alert",
    "crit",
    "err",
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
for line in journal.splitlines():
    line_attrs = parse_attrs(line)
    if "facility" in line_attrs:
        has_facility = True
        assert "facility_label" in line_attrs, (
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
        assert line_attrs["facility_label"] in valid_facilities, (
            f"unexpected facility_label: {line_attrs['facility_label']}"
        )
        break

assert has_facility, "no log records with facility label found"
print("Log pipeline test passed!")