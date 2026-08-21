{
  lib,
  config,
  ...
}:
with lib;
with types;
let
  cfg = config.telemetry.apps.netdata;
in
{
  options.telemetry.apps.netdata = {
    enable = mkOption {
      type = bool;
      default = config.telemetry.metrics.enable;
      description = ''
        enable netdata to collect metrics.
      '';
    };
    port = mkOption {
      type = int;
      default = 19999;
      description = ''
        Port netdata exposes its metrics on.
      '';
    };
  };

  config = mkMerge [

    # configure netdata
    # -----------------
    (mkIf config.telemetry.apps.netdata.enable {
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
    (mkIf (config.telemetry.apps.netdata.enable && config.telemetry.apps.opentelemetry.enable) {
      services.opentelemetry-collector.settings = {

        service.pipelines.metrics.receivers = [ "prometheus" ];

        receivers.prometheus.config.scrape_configs = [
          {
            job_name = "netdata";
            scrape_interval = "10s";
            metrics_path = "/api/v1/allmetrics";
            params.format = [ "prometheus" ];
            static_configs = [ { targets = [ "127.0.0.1:${toString cfg.port}" ]; } ];
          }
        ];
      };
    })
  ];
}
