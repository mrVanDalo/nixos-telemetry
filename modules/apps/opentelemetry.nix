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
    exporter.endpoints = mkOption {
      type = attrsOf str;
      default = { };
      example = {
        primary = "100.0.0.1:4317";
        backup = "100.0.0.2:4317";
      };
      description = ''
        Named OTLP/gRPC endpoints to ship telemetry to.
        Each attribute becomes a separate `otlp/<name>` exporter so the
        collector can fan out to one or more downstream collectors
        simultaneously.
      '';
    };
    exporter.debug = mkOption {
      type = nullOr (enum [
        "logs"
        "metrics"
      ]);
      default = null;
      description = "enable debug exporter.";
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

          # copy the systemd `unit` log attribute (set by alloy's relabel rules)
          # onto the resource as `service.name`, so Loki promotes it to the
          # `service_name` stream label (service.name is one of Loki's default
          # OTLP index labels). This lets logs be filtered by service_name
          # instead of all collapsing to Loki's "unknown_service" fallback.
          # See: https://grafana.com/docs/loki/latest/get-started/labels/
          "transform/service_name" = {
            log_statements = [
              {
                context = "log";
                statements = [
                  ''set(attributes["service.name"], attributes["unit"]) where attributes["unit"] != nil''
                  # strip common systemd unit suffixes for a clean service name
                  # (grafana.service -> grafana, session.scope -> session)
                  ''replace_pattern(attributes["service.name"], "\\.(service|socket|timer|target|scope|mount|swap|slice|automount|device)$", "") where attributes["service.name"] != nil''
                ];
              }
            ];
          };

          # The loki receiver puts every stream of a push request under a single
          # ResourceLogs, so a resource attribute can only describe one service.
          # groupbyattrs splits the records back out: it moves the `service.name`
          # log attribute onto the Resource (one ResourceLogs per distinct
          # service) so each service gets its own stream in Loki.
          # https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/processor/groupbyattrsprocessor
          "groupbyattrs/service" = {
            keys = [ "service.name" ];
          };

          metricstransform.transforms = [
            {
              include = ".*";
              match_type = "regexp";
              action = "update";
              operations = [
                {
                  action = "add_label";
                  new_label = "host_name";
                  new_value = config.networking.hostName;
                }
              ];
            }
          ];
        };
      };
    })
    # wire metrics processors (only when both a source and sink exist, otherwise no pipeline)
    (mkIf
      (
        config.telemetry.metrics.enable
        && config.telemetry.apps.opentelemetry.enable
        && config.telemetry.metrics.hasSource
        && config.telemetry.metrics.hasSink
      )
      {
        services.opentelemetry-collector.settings = {
          service.pipelines.metrics.processors = [
            "metricstransform"
            "resourcedetection/system"
          ];
        };
      }
    )
    # wire logs processors (only when both a source and sink exist, otherwise no pipeline)
    (mkIf
      (
        config.telemetry.logs.enable
        && config.telemetry.apps.opentelemetry.enable
        && config.telemetry.logs.hasSource
        && config.telemetry.logs.hasSink
      )
      {
        services.opentelemetry-collector.settings = {
          service.pipelines.logs.processors = [
            "resourcedetection/system"
            "transform/service_name"
            "groupbyattrs/service"
          ];
        };
      }
    )

    # enable debug logs or metrics
    # ----------------------------
    (mkIf
      (
        cfg.exporter.debug != null
        && config.telemetry.apps.opentelemetry.enable
        && config.telemetry.${cfg.exporter.debug}.hasSource
      )
      {
        services.opentelemetry-collector.settings = {
          exporters.debug = {
            verbosity = "normal";
            sampling_initial = 5;
            sampling_thereafter = 200;
          };
          service.pipelines.${cfg.exporter.debug} = {
            exporters = [ "debug" ];
          };
        };
      }
    )

    # ship to downstream instances
    # ---------------------------
    (mkIf (cfg.exporter.endpoints != { } && config.telemetry.apps.opentelemetry.enable) {
      services.opentelemetry-collector.settings.exporters = mapAttrs' (name: endpoint: {
        name = "otlp/${name}";
        value = {
          endpoint = mkDefault endpoint;
          tls.insecure = mkDefault true;
        };
      }) cfg.exporter.endpoints;
    })
    (mkIf
      (
        cfg.exporter.endpoints != { }
        && config.telemetry.logs.enable
        && config.telemetry.apps.opentelemetry.enable
        && config.telemetry.logs.hasSource
      )
      {
        services.opentelemetry-collector.settings.service.pipelines.logs.exporters = map (
          name: "otlp/${name}"
        ) (attrNames cfg.exporter.endpoints);
      }
    )
    (mkIf
      (
        cfg.exporter.endpoints != { }
        && config.telemetry.metrics.enable
        && config.telemetry.apps.opentelemetry.enable
        && config.telemetry.metrics.hasSource
      )
      {
        services.opentelemetry-collector.settings.service.pipelines.metrics.exporters = map (
          name: "otlp/${name}"
        ) (attrNames cfg.exporter.endpoints);
      }
    )

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
      && config.telemetry.logs.hasSink
    ) { services.opentelemetry-collector.settings.service.pipelines.logs.receivers = [ "otlp" ]; })
    (mkIf (
      config.telemetry.apps.opentelemetry.receiver.endpoint != null
      && config.telemetry.metrics.enable
      && config.telemetry.apps.opentelemetry.enable
      && config.telemetry.metrics.hasSink
    ) { services.opentelemetry-collector.settings.service.pipelines.metrics.receivers = [ "otlp" ]; })

    # disable collector internal metrics
    # -----------------------------------
    (mkIf config.telemetry.apps.opentelemetry.enable {
      services.opentelemetry-collector.settings = {
        service.telemetry.metrics.level = "none";
      };
    })
  ];

}
