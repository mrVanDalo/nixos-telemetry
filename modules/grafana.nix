{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.telemetry.grafana;
in
{
  options.telemetry.grafana = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Enable Grafana and auto-provision datasources for any
        telemetry backends that are enabled (Loki, Prometheus).
      '';
    };
    http_port = lib.mkOption {
      type = lib.types.int;
      default = 3000;
      description = ''
        Port the Grafana HTTP server listens on.
      '';
    };
    http_addr = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = ''
        Address the Grafana HTTP server listens on.
      '';
    };
    autogenerateSecretKey = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Automatically generate a persistent Grafana secret key on first
        start and point `security.secret_key` at it via `$__file{}`.
        Disable to manage the secret key yourself.
      '';
    };
    adminAccess = lib.mkOption {
      type = lib.types.enum [
        "anonymous"
        "autogenerate"
        "firstLoginChange"
      ];
      default = "firstLoginChange";
      description = ''
        How the initial admin account access is configured:
        - `anonymous`: anonymous access is enabled with the Viewer role,
          so dashboards can be viewed without logging in.
        - `autogenerate`: a random admin password is generated on first
          start and stored in a file referenced via `$__file{}`.
          No anonymous access.
        - `firstLoginChange`: the default admin credentials are used and
          Grafana forces a password change on first login. No anonymous
          access.
      '';
    };

  };

  config = lib.mkMerge [

    # enable grafana service
    # ----------------------
    (lib.mkIf (config.telemetry.enable && cfg.enable) {
      services.grafana = {
        enable = lib.mkDefault true;
        settings = {
          server = {
            http_listen_port = cfg.http_port;
            http_addr = cfg.http_addr;
          };
          users.default_theme = "system";
          security = {
            admin_user = lib.mkDefault "admin";
          };
          analytics.reporting_enabled = false;
        };
      };
    })

    # Generates a persistent secret key on first start via ExecStartPre
    # this way the log generation information ends up in the grafana logs
    (
      let
        secretKeyFile = "${config.services.grafana.dataDir}/secret_key";
      in
      lib.mkIf (config.telemetry.enable && cfg.enable && cfg.autogenerateSecretKey) {
        services.grafana.settings.security.secret_key = lib.mkDefault "$__file{${secretKeyFile}}";
        systemd.services.grafana.serviceConfig.ExecStartPre = lib.mkBefore [
          (lib.getExe (
            pkgs.writeShellScriptBin "grafana-generate-secret-key" ''
              umask 077
              if [ ! -f ${secretKeyFile} ]; then
                echo ""
                echo "╔═══════════════════════════════════════════════════════════════"
                echo "║  Generating Grafana secret key"
                echo "║  at ${secretKeyFile}"
                echo "╚═══════════════════════════════════════════════════════════════"
                echo ""
                ${lib.getExe' pkgs.openssl "openssl"} rand -hex 32 > ${secretKeyFile}
              else
                echo ""
                echo "╔═══════════════════════════════════════════════════════════════"
                echo "║  Grafana secret key already exists, skipping generation"
                echo "║  at ${secretKeyFile}"
                echo "╚═══════════════════════════════════════════════════════════════"
                echo ""
              fi
            ''
          ))
        ];
      }
    )

    # admin access: auto-generated password
    # -------------------------------------
    # Generates a random admin password on first start via ExecStartPre,
    # mirroring the secret key generation pattern.
    (
      let
        adminPasswordFile = "${config.services.grafana.dataDir}/admin_password";
      in
      lib.mkIf (config.telemetry.enable && cfg.enable && cfg.adminAccess == "autogenerate") {
        services.grafana.settings.security.admin_password = lib.mkDefault "$__file{${adminPasswordFile}}";
        services.grafana.settings."auth.anonymous".enabled = lib.mkDefault false;
        systemd.services.grafana.serviceConfig.ExecStartPre = lib.mkBefore [
          (lib.getExe (
            pkgs.writeShellScriptBin "grafana-generate-admin-password" ''
              umask 077
              if [ ! -f ${adminPasswordFile} ]; then
                echo ""
                echo "╔═══════════════════════════════════════════════════════════════"
                echo "║  Generating Grafana admin password"
                echo "║  at ${adminPasswordFile}"
                echo "╚═══════════════════════════════════════════════════════════════"
                echo ""
                ${lib.getExe' pkgs.openssl "openssl"} rand -base64 24 > ${adminPasswordFile}
              else
                echo ""
                echo "╔═══════════════════════════════════════════════════════════════"
                echo "║  Grafana admin password already exists, skipping generation"
                echo "║  at ${adminPasswordFile}"
                echo "╚═══════════════════════════════════════════════════════════════"
                echo ""
              fi
            ''
          ))
        ];
      }
    )

    # admin access: anonymous viewer access
    # -------------------------------------
    (lib.mkIf (config.telemetry.enable && cfg.enable && cfg.adminAccess == "anonymous") {
      services.grafana.settings."auth.anonymous" = {
        enabled = lib.mkDefault true;
        org_role = lib.mkDefault "Admin";
      };
    })

    # admin access: force first-login password change
    # ------------------------------------------------
    # No anonymous access: real login required so the first-login
    # password change is actually triggered.
    (lib.mkIf (config.telemetry.enable && cfg.enable && cfg.adminAccess == "firstLoginChange") {
      services.grafana.settings."auth.anonymous".enabled = lib.mkDefault false;
    })

    # provision prometheus datasource
    # -------------------------------
    (lib.mkIf (config.telemetry.enable && cfg.enable && config.telemetry.prometheus.enable) {
      services.grafana.provision.datasources.settings.datasources = [
        {
          name = "OTLP Prometheus";
          type = "prometheus";
          access = "proxy";
          url = "http://127.0.0.1:${toString config.services.prometheus.port}";
          isDefault = true;
          jsonData = {
            timeInterval = "10s";
          };
        }
      ];
    })

    # provision loki datasource
    # -------------------------
    (lib.mkIf (config.telemetry.enable && cfg.enable && config.telemetry.loki.enable) {
      services.grafana.provision.datasources.settings.datasources = [
        {
          name = "OTLP Loki";
          type = "loki";
          access = "proxy";
          url = "http://127.0.0.1:${toString config.telemetry.loki.port}";
          isDefault = false;
          jsonData = {
            maxLines = 1000;
          };
        }
      ];
    })

  ];
}
