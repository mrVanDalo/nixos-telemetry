{ config, lib, ... }:
with lib;
with types;
let
  cfg = config.telemetry.prometheus;
in
{
  options.telemetry.prometheus = {
    enable = mkOption {
      type = lib.types.bool;
      default = config.telemetry.metrics.enable;
    };
    port = mkOption {
      type = int;
      default = 8090;
      description = "port to provide Prometheus export";
    };
  };

  config = mkMerge [

    # configure prometheus
    # --------------------
    (mkIf config.telemetry.prometheus.enable {
      services.prometheus = {
        checkConfig = "syntax-only";
        enable = true;
      };
    })

    # provide opentelemetry prometheus exporter
    # -----------------------------------------
    (mkIf (config.telemetry.prometheus.enable && config.telemetry.opentelemetry.enable) {
      services.opentelemetry-collector.settings = {
        exporters.prometheus.endpoint = "127.0.0.1:${toString cfg.port}";
        service.pipelines.metrics.exporters = [ "prometheus" ];
      };
      services.prometheus.scrapeConfigs = [
        {
          job_name = "opentelemetry";
          metrics_path = "/metrics";
          scrape_interval = "10s";
          static_configs = [ { targets = [ "localhost:${toString cfg.port}" ]; } ];
        }
      ];
    })

  ];
}
