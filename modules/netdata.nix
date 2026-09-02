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
          enable netdata to collect metrics.
        '';
      };
    };
    telemetry.ports.netdata = mkOption {
      type = int;
      default = 19999;
      description = ''
        Port netdata exposes its metrics on.
        The OpenTelemetry collector scrapes metrics from this port.
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
    (mkIf (config.telemetry.enable && cfg.enable && config.telemetry.pipelines.metrics.hasSink) {
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
    })
  ];
}
