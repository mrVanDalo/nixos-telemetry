{
  pkgs,
  config,
  lib,
  ...
}:
with lib;
with types;
let
  cfg = config.telemetry.apps.opentelemetry;
in
{
  options.telemetry.apps.opentelemetry = {
    enable = mkOption {
      type = bool;
      default = config.telemetry.enable;
      description = "enable opentelemetry collector";
    };
    receiver.endpoint = mkOption {
      type = nullOr str;
      default = null;
      example = "0.0.0.0:4317";
      description = "endpoint to receive the opentelementry collector data from other collectors";
    };
    exporter.endpoint = mkOption {
      type = nullOr str;
      default = null;
      example = "100.0.0.1:4317";
      description = "endpoint to ship data to the next opentelementry collector";
    };
    exporter.debug = mkOption {
      type = nullOr (enum [
        "logs"
        "metrics"
      ]);
      default = null;
      description = "enable debug exporter.";
    };
    metrics.endpoint = mkOption {
      type = str;
      default = "127.0.0.1:8100";
      description = "endpoint on where to provide opentelementry collector metrics";
    };
  };

  config = mkMerge [

    # enable opentelemetry collector
    # ------------------------------
    (mkIf config.telemetry.apps.opentelemetry.enable {
      services.opentelemetry-collector = {
        enable = mkDefault true;
        package = mkDefault pkgs.opentelemetry-collector-contrib;
      };

      # some handy scripts
      # todo : use a nice yaml viewer here
      environment.systemPackages = [
        (pkgs.writers.writeBashBin "opentelemetry-show-config" ''
          cat $(systemctl cat opentelemetry-collector | grep -oP '(?<=--config=file:)\S+')
        '')
      ];
    })

    # add default tags processors
    # ---------------------------
    (mkIf (config.telemetry.apps.opentelemetry.enable) {

      services.opentelemetry-collector.settings = {

        processors = {

          # todo  : add a tag for nixos-container name

          # https://github.com/open-telemetry/opentelemetry-collector-contrib/blob/main/processor/resourcedetectionprocessor/README.md
          "resourcedetection/system" = {
            detectors = [ "system" ];
            override = false;
            system.hostname_sources = [ "os" ];
          };

          metricstransform.transforms = [
            {
              include = ".*";
              match_type = "regexp";
              action = "update";
              operations = [
                {
                  action = "add_label";
                  new_label = "machine"; # todo : use the same here as for logs (host_name)
                  new_value = config.networking.hostName;
                }
              ];
            }
          ];
        };
      };
    })
    # wire metrics processors
    (mkIf (config.telemetry.metrics.enable && config.telemetry.apps.opentelemetry.enable) {
      services.opentelemetry-collector.settings = {
        service.pipelines.metrics.processors = [
          "metricstransform"
          "resourcedetection/system"
        ];
      };
    })
    # wire logs processors
    (mkIf (config.telemetry.logs.enable && config.telemetry.apps.opentelemetry.enable) {
      services.opentelemetry-collector.settings = {
        service.pipelines.logs.processors = [ "resourcedetection/system" ];
      };
    })

    # enable debug logs or metrics
    # ----------------------------
    (mkIf
      (
        config.telemetry.apps.opentelemetry.exporter.debug != null
        && config.telemetry.apps.opentelemetry.enable
      )
      {
        services.opentelemetry-collector.settings = {
          exporters.debug = {
            verbosity = "detailed";
            sampling_initial = 5;
            sampling_thereafter = 200;
          };
          service.pipelines.${config.telemetry.opentelemetry.exporter.debug} = {
            exporters = [ "debug" ];
          };
        };
      }
    )

    # ship to next instance
    # ---------------------
    (mkIf
      (
        config.telemetry.apps.opentelemetry.exporter.endpoint != null
        && config.telemetry.apps.opentelemetry.enable
      )
      {
        services.opentelemetry-collector.settings = {
          exporters.otlp = {
            endpoint = mkDefault cfg.exporter.endpoint;
            tls.insecure = mkDefault true;
          };
        };
      }
    )
    (mkIf (
      config.telemetry.apps.opentelemetry.exporter.endpoint != null
      && config.telemetry.logs.enable
      && config.telemetry.apps.opentelemetry.enable
    ) { services.opentelemetry-collector.settings.service.pipelines.logs.exporters = [ "otlp" ]; })
    (mkIf (
      config.telemetry.apps.opentelemetry.exporter.endpoint != null
      && config.telemetry.metrics.enable
      && config.telemetry.apps.opentelemetry.enable
    ) { services.opentelemetry-collector.settings.service.pipelines.metrics.exporters = [ "otlp" ]; })

    # receive from other instances
    # ----------------------------
    (mkIf
      (
        config.telemetry.apps.opentelemetry.receiver.endpoint != null
        && config.telemetry.apps.opentelemetry.enable
      )
      {
        services.opentelemetry-collector.settings.receivers.otlp.protocols.grpc.endpoint =
          cfg.receiver.endpoint;
      }
    )
    (mkIf (
      config.telemetry.apps.opentelemetry.receiver.endpoint != null
      && config.telemetry.logs.enable
      && config.telemetry.apps.opentelemetry.enable
    ) { services.opentelemetry-collector.settings.service.pipelines.logs.receivers = [ "otlp" ]; })
    (mkIf (
      config.telemetry.apps.opentelemetry.receiver.endpoint != null
      && config.telemetry.metrics.enable
      && config.telemetry.apps.opentelemetry.enable
    ) { services.opentelemetry-collector.settings.service.pipelines.metrics.receivers = [ "otlp" ]; })

    # scrape opentelemetry collectors metrics
    # --------------------------------------
    # todo: this should be collected another way (opentelemetry internal?)
    # todo : enable me only when metrics.endpoint is set.
    (mkIf (config.telemetry.metrics.enable && config.telemetry.apps.opentelemetry.enable) {
      services.opentelemetry-collector.settings = {
        receivers = {
          prometheus.config.scrape_configs = [
            {
              job_name = "otelcol";
              scrape_interval = "10s";
              static_configs = [
                {
                  targets = [ cfg.metrics.endpoint ];
                }
              ];
              metric_relabel_configs = [
                {
                  source_labels = [ "__name__" ];
                  regex = ".*grpc_io.*";
                  action = "drop";
                }
              ];
            }
          ];
        };

        service = {
          pipelines.metrics = {
            receivers = [ "prometheus" ];
          };

          # todo : this should be automatically be collected
          # open telemetries own metrics?
          telemetry.metrics.address = cfg.metrics.endpoint;
        };

      };
    })
    # disable opentelemetry collectors metrics
    (mkIf (!config.telemetry.metrics.enable && config.telemetry.apps.opentelemetry.enable) {
      services.opentelemetry-collector.settings = {
        service.telemetry.metrics.level = "none";
      };
    })
  ];

}
