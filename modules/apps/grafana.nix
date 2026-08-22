{ config, lib, ... }:
let
  cfg = config.telemetry.apps.grafana;
in
{
  options.telemetry.apps.grafana = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Enable Grafana and auto-provision datasources for any
        telemetry backends that are enabled (Loki, Prometheus).
      '';
    };
    port = lib.mkOption {
      type = lib.types.int;
      default = 3000;
      description = ''
        Port the Grafana HTTP server listens on.
      '';
    };
    secretKey = lib.mkOption {
      type = lib.types.str;
      default = "SW2YcwTIb9zpOOhoPsMm";
      description = ''
        Secret key used by Grafana for encrypting secrets in the database.
        Override this in production with a unique value.
      '';
    };
  };

  config = lib.mkMerge [

    # enable grafana service
    # ----------------------
    (lib.mkIf cfg.enable {
      services.grafana = {
        enable = lib.mkDefault true;
        settings = {
          server.http_listen_port = cfg.port;
          security.secret_key = cfg.secretKey;
          "auth.anonymous" = {
            enabled = lib.mkDefault true;
            org_role = lib.mkDefault "Admin";
          };
          analytics.reporting_enabled = false;
        };
      };
    })

    # provision prometheus datasource
    # ------------------------------
    (lib.mkIf (cfg.enable && config.telemetry.apps.prometheus.enable) {
      services.grafana.provision.datasources.settings.datasources = [
        {
          name = "Prometheus";
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
    (lib.mkIf (cfg.enable && config.telemetry.apps.loki.enable) {
      services.grafana.provision.datasources.settings.datasources = [
        {
          name = "Loki";
          type = "loki";
          access = "proxy";
          url = "http://127.0.0.1:${toString config.telemetry.apps.loki.port}";
          isDefault = false;
          jsonData = {
            maxLines = 1000;
          };
        }
      ];
    })

  ];
}
