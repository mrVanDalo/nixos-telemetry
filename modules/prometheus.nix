{ config, lib, ... }:
with lib;
with types;
let
  cfg = config.telemetry.prometheus;
in
{
  options = {
    telemetry.prometheus = {
      enable = mkOption {
        type = bool;
        default = false;
        description = ''
          Convenience option that enables `services.prometheus.enable` with opinionated
          defaults and wires it as a metrics sink into the OpenTelemetry collector.

          Even without this flag, if `services.prometheus.enable = true` is set directly,
          the collector exposes its Prometheus endpoint and Prometheus scrapes it
          automatically.
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
    (mkIf (config.telemetry.enable && cfg.enable) {
      services.prometheus = {
        enable = true;
        checkConfig = mkDefault "syntax-only";
        extraFlags = mkDefault [ "--storage.tsdb.retention.time=${cfg.retentionTime}" ];
      };
    })

    # provide opentelemetry prometheus exporter
    # -----------------------------------------
    (mkIf
      (
        config.telemetry.enable
        && config.services.prometheus.enable
        && config.telemetry.pipelines.metrics.hasReceiver
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
