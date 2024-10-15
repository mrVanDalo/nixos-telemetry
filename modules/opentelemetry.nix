{
  pkgs,
  config,
  lib,
  ...
}:
with lib;
with types;
let
  cfg = config.telemetry.opentelemetry;
in
{
  options.telemetry.opentelemetry = {
    enable = mkOption {
      type = bool;
      default = config.telemetry.enable;
      description = "weather or not to use opentelemetry";
    };
    receiver.endpoint = mkOption {
      type = nullOr str;
      default = null;
      description = "endpoint to receive the opentelementry data from other collectors";
    };
    exporter.endpoint = mkOption {
      type = nullOr str;
      default = null;
      description = "endpoint to ship opentelementry data too";
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
      description = "endpoint on where to provide opentelementry metrics";
    };
  };

  config = mkMerge [

    (mkIf config.telemetry.opentelemetry.enable {
      services.opentelemetry-collector = {
        enable = true;
        package = pkgs.opentelemetry-collector-contrib;
      };

      # some handy scripts
      # todo : use a nice yaml viewer here
      environment.systemPackages = [
        (pkgs.writers.writeBashBin "show-opentelemetry-config" ''
          cat $(systemctl cat opentelemetry-collector | grep -oP '(?<=--config=file:)\S+')
        '')
      ];
    })

    # add default tags to metrics
    # todo : make sure we filter out metrics from otlp receivers
    (mkIf config.telemetry.enable {
      services.opentelemetry-collector.settings = {

        processors = {

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
                  new_label = "machine";
                  new_value = config.networking.hostName;
                }
              ];
            }
          ];
        };
      };
    })
    (mkIf config.telemetry.metrics.enable {
      services.opentelemetry-collector.settings = {
        service.pipelines.metrics.processors = [
          "metricstransform"
          "resourcedetection/system"
        ];
      };
    })
    (mkIf config.telemetry.logs.enable {
      services.opentelemetry-collector.settings = {
        service.pipelines.logs.processors = [ "resourcedetection/system" ];
      };
    })

    (mkIf (config.telemetry.opentelemetry.exporter.debug != null) {
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
    })

    # ship to next instance
    # ---------------------
    (mkIf (config.telemetry.opentelemetry.exporter.endpoint != null) {
      services.opentelemetry-collector.settings = {
        exporters.otlp = {
          endpoint = cfg.exporter.endpoint;
          tls.insecure = true;
        };
      };
    })
    (mkIf (config.telemetry.opentelemetry.exporter.endpoint != null && config.telemetry.logs.enable) {
      services.opentelemetry-collector.settings = {
        service.pipelines.logs.exporters = [ "otlp" ];
      };
    })
    (mkIf (config.telemetry.opentelemetry.exporter.endpoint != null && config.telemetry.metrics.enable)
      {
        services.opentelemetry-collector.settings = {
          service.pipelines.metrics.exporters = [ "otlp" ];
        };
      }
    )

    # ship from other instance
    # ------------------------
    (mkIf (config.telemetry.opentelemetry.receiver.endpoint != null) {
      services.opentelemetry-collector.settings = {
        receivers.otlp.protocols.grpc.endpoint = cfg.receiver.endpoint;
      };
    })
    (mkIf (config.telemetry.opentelemetry.receiver.endpoint != null && config.telemetry.logs.enable) {
      services.opentelemetry-collector.settings = {
        service.pipelines.logs.receivers = [ "otlp" ];
      };
    })
    (mkIf (config.telemetry.opentelemetry.receiver.endpoint != null && config.telemetry.metrics.enable)
      {
        services.opentelemetry-collector.settings = {
          service.pipelines.metrics.receivers = [ "otlp" ];
        };
      }
    )

    # scrape opentelemetry-colectors metrics
    # todo: this should be collected another way (opentelemetry internal?)
    # todo : enable me only when metrics.endpoint is set.
    (mkIf config.telemetry.metrics.enable {
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
    (mkIf (!config.telemetry.metrics.enable) {
      services.opentelemetry-collector.settings = {
        service.telemetry.metrics.level = "none";
      };
    })
  ];

}
