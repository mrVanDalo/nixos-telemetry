{
  lib,
  pkgs,
  config,
  ...
}:
with lib;
with types;
let
  netdataPort = 19999;
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
  };

  config = mkMerge [

    # configure netdata
    # -----------------
    (mkIf config.telemetry.apps.netdata.enable {
      # https://docs.netdata.cloud/daemon/config/
      services.netdata = {
        enable = lib.mkDefault true;
        config = {
          # todo: configure netdataPort and reference it in the opentelemetry configuration
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
            static_configs = [ { targets = [ "127.0.0.1:${toString netdataPort}" ]; } ];
          }
        ];
      };
    })
  ];
}
