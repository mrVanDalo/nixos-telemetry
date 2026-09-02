{
  lib,
  config,
  ...
}:
with lib;
with types;
let
  cfg = config.telemetry.netdata;
in
{
  options = {
    telemetry.netdata = {
      enable = mkOption {
        type = bool;
        default = false;
        description = ''
          Convenience option that enables `services.netdata.enable` with opinionated
          defaults and wires it as a metrics source into the OpenTelemetry collector.

          Even without this flag, if `services.netdata.enable = true` is set directly,
          the OTel wiring still happens automatically — the collector scrapes metrics
          from any enabled Netdata instance.
        '';
      };
    };
    telemetry.ports.netdata = mkOption {
      type = int;
      default = 19999;
      description = ''
        Prometheus receiver port opened by the OpenTelemetry collector.
        Netdata exposes metrics that the OpenTelemetry collector scrapes from this port.
      '';
    };
  };

  config = mkMerge [

    # configure netdata
    # -----------------
    (mkIf (config.telemetry.enable && cfg.enable) {
      # https://docs.netdata.cloud/daemon/config/
      services.netdata = {
        enable = lib.mkDefault true;
        config = {
          global = {
            "memory mode" = "ram";
          };
        };
      };
    })

    # wire netdata with opentelemetry
    # -------------------------------
    (mkIf
      (
        config.telemetry.enable
        && config.services.netdata.enable
        && config.telemetry.pipelines.metrics.hasExporter
      )
      {
        services.opentelemetry-collector.settings = {

          service.pipelines.metrics.receivers = [ "prometheus" ];

          receivers.prometheus.config.scrape_configs = [
            {
              job_name = "netdata";
              scrape_interval = "10s";
              metrics_path = "/api/v1/allmetrics";
              params.format = [ "prometheus" ];
              static_configs = [ { targets = [ "127.0.0.1:${toString config.telemetry.ports.netdata}" ]; } ];
            }
          ];
        };
      }
    )
  ];
}
