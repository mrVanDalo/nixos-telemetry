{ config, lib, ... }:
with lib;
with types;
{
  options = {
    telemetry.prometheus = {
      enable = mkOption {
        type = bool;
        default = false;
        description = ''
          Enable Prometheus as a metrics storage backend. When combined with
          `telemetry.enable`, Prometheus scrapes the metrics the OpenTelemetry
          collector exposes.
        '';
      };
      retentionTime = mkOption {
        type = str;
        default = "30d";
        description = ''
          How long Prometheus retains collected metrics before deleting them.
          If you want to store metrics for a really long time, use thanos.
        '';
      };
    };
    telemetry.ports.prometheus = mkOption {
      type = int;
      default = 8090;
      description = ''
        Port the OpenTelemetry collector exposes Prometheus metrics on.
        Prometheus scrapes this port.
      '';
    };
  };

  config = mkMerge [

    # configure prometheus
    # --------------------
    (mkIf (config.telemetry.enable && config.telemetry.prometheus.enable) {
      services.prometheus = {
        checkConfig = mkDefault "syntax-only";
        enable = mkDefault true;
        extraFlags = mkDefault [
          "--storage.tsdb.retention.time=${config.telemetry.prometheus.retentionTime}"
        ];
      };
    })

    # provide opentelemetry prometheus exporter
    # -----------------------------------------
    (mkIf
      (
        config.telemetry.enable
        && config.telemetry.prometheus.enable
        && config.telemetry.pipelines.metrics.hasReceivers
      )
      {
        services.opentelemetry-collector.settings = {
          service.pipelines.metrics.exporters = [ "prometheus" ];
          exporters.prometheus.endpoint = "127.0.0.1:${toString config.telemetry.ports.prometheus}";
        };

        services.prometheus.scrapeConfigs = [
          {
            job_name = "opentelemetry";
            metrics_path = "/metrics";
            scrape_interval = "10s";
            static_configs = [ { targets = [ "localhost:${toString config.telemetry.ports.prometheus}" ]; } ];
          }
        ];

      }
    )

  ];
}
