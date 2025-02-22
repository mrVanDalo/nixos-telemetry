{ config, lib, ... }:
with lib;
with types;
let
  cfg = config.telemetry.apps.prometheus;
in
{
  options.telemetry.apps.prometheus = {
    enable = mkOption {
      type = bool;
      default = false;
      description = ''
        enable prometheus and configure it to scrape opentelemetry collector metrics
        (in case `telemetry.apps.opentelemetry.enable = true`).
      '';
    };
    port = mkOption {
      type = int;
      default = 8090;
      description = ''
        opentelemetry collector port to expose metrics for prometheus.
      '';
    };
    retentionTime = mkOption {
      type = str;
      default = "30d";
      description = ''
        retention time of prometheus data. If you want to serialize a really long time, use thanos.
      '';
    };
  };

  config = mkMerge [

    # configure prometheus
    # --------------------
    (mkIf config.telemetry.apps.prometheus.enable {
      services.prometheus = {
        checkConfig = mkDefault "syntax-only";
        enable = mkDefault true;
        extraFlags = mkDefault [ "--storage.tsdb.retention.time=${toString cfg.retentionTime}" ];
      };
    })

    # provide opentelemetry prometheus exporter
    # -----------------------------------------
    (mkIf (config.telemetry.apps.prometheus.enable && config.telemetry.apps.opentelemetry.enable) {
      services.opentelemetry-collector.settings = {
        service.pipelines.metrics.exporters = [ "prometheus" ];
        exporters.prometheus.endpoint = "127.0.0.1:${toString cfg.port}";
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
