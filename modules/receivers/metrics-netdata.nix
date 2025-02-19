{
  lib,
  pkgs,
  config,
  ...
}:
with lib;
with types;
{
  options.telemetry.netdata = {
    enable = mkOption {
      type = bool;
      default = config.telemetry.metrics.enable;
      description = "todo";
    };
  };

  config = mkIf config.telemetry.netdata.enable {

    # https://docs.netdata.cloud/daemon/config/
    services.netdata = {
      enable = lib.mkDefault true;
      config = {
        global = {
          "memory mode" = "ram";
        };
      };
    };

    # netdata sink
    # todo: only if opentelemetry is enabled
    services.opentelemetry-collector.settings.receivers.prometheus.config.scrape_configs = [
      {
        job_name = "netdata";
        scrape_interval = "10s";
        metrics_path = "/api/v1/allmetrics";
        params.format = [ "prometheus" ];
        static_configs = [ { targets = [ "127.0.0.1:19999" ]; } ];
      }
    ];

  };
}
