start_all()

# ── grafana should start (ExecStartPre generates the secret key) ─────
machine.wait_for_unit("grafana.service")
machine.succeed("systemctl is-active grafana.service")
machine.wait_for_open_port(3000)

# ── secret key file should exist with mode 0600 ──────────────────────
# The ExecStartPre generates a random 32-byte hex key (64 chars) with
# umask 077, only if the file does not already exist.
secret_key_mode = machine.succeed("stat -c '%a' /var/lib/grafana/secret_key").strip()
assert secret_key_mode == "600", f"secret_key file mode is {secret_key_mode}, expected 600"

secret_key = machine.succeed("cat /var/lib/grafana/secret_key").strip()
assert len(secret_key) == 64, (
    f"secret_key is {len(secret_key)} chars, expected 64 (32 bytes hex)"
)
assert all(c in "0123456789abcdef" for c in secret_key), (
    "secret_key should be hex characters only"
)
print(f"Secret key verified: {len(secret_key)} hex chars, mode 0600")

# ── grafana should respond with a health check ──────────────────────
machine.succeed("curl -sf http://127.0.0.1:3000/api/health | grep -q 'ok'")
print("Grafana healthy with $__file{...} secret expansion")

# ── grafana config should use $__file{...} not the raw key ──────────
exec_start = machine.succeed("systemctl show -p ExecStart --value grafana.service")
config_path = exec_start.split(" -config ")[1].split(";")[0].strip()
grafana_config = machine.succeed(f"cat {config_path}")
assert "$__file{/var/lib/grafana/secret_key}" in grafana_config, (
    "Grafana config should reference secret_key via $__file{...} expansion"
)
assert secret_key not in grafana_config, (
    "Raw secret key must not appear in the generated config"
)
print("Config verified: $__file{...} expansion, no raw key in config")

# ── admin login should work with default password ───────────────────
# admin_password is left unset (nixpkgs default "admin"), forcing a
# first-login password change.
datasources = machine.succeed(
    "curl -sf -u admin:admin http://127.0.0.1:3000/api/datasources"
)
print("Admin login verified with default password")

# ──────────────────────────────────────────────────────────────────────
# autogen node: adminAccess = "autogenerate"
# ──────────────────────────────────────────────────────────────────────
autogen.wait_for_unit("grafana.service")
autogen.succeed("systemctl is-active grafana.service")
autogen.wait_for_open_port(3000)

# ── admin password file should exist with mode 0600 ─────────────────
# The ExecStartPre generates a random base64 password with umask 077,
# only if the file does not already exist.
admin_pw_mode = autogen.succeed("stat -c '%a' /var/lib/grafana/admin_password").strip()
assert admin_pw_mode == "600", f"admin_password file mode is {admin_pw_mode}, expected 600"

admin_pw = autogen.succeed("cat /var/lib/grafana/admin_password").strip()
assert len(admin_pw) > 0, "admin_password file should not be empty"
print(f"Admin password verified: {len(admin_pw)} chars, mode 0600")

# ── grafana should respond with a health check ──────────────────────
autogen.succeed("curl -sf http://127.0.0.1:3000/api/health | grep -q 'ok'")
print("autogen Grafana healthy")

# ── grafana config should use $__file{...} for admin_password ──────
autogen_exec_start = autogen.succeed("systemctl show -p ExecStart --value grafana.service")
autogen_config_path = autogen_exec_start.split(" -config ")[1].split(";")[0].strip()
autogen_config = autogen.succeed(f"cat {autogen_config_path}")
assert "$__file{/var/lib/grafana/admin_password}" in autogen_config, (
    "Grafana config should reference admin_password via $__file{...} expansion"
)
assert admin_pw not in autogen_config, (
    "Raw admin password must not appear in the generated config"
)
print("autogen config verified: $__file{...} expansion, no raw password in config")

# ── admin login should work with the generated password ─────────────
autogen.succeed(
    f"curl -sf -u admin:{admin_pw} http://127.0.0.1:3000/api/datasources"
)
print("autogen admin login verified with generated password")

# ── default admin:admin should NOT work ─────────────────────────────
autogen.fail(
    "curl -sf -u admin:admin http://127.0.0.1:3000/api/datasources"
)
print("autogen: default admin:admin login correctly rejected")

# ── anonymous access should be disabled ─────────────────────────────
autogen.fail(
    "curl -sf http://127.0.0.1:3000/api/datasources"
)
print("autogen: anonymous access correctly disabled")


print("grafana-secrets test passed!")