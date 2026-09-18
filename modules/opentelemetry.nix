{
  pkgs,
  config,
  lib,
  ...
}:
with lib;
with types;
{
  options.telemetry.opentelemetry = {
    receiver.endpoint = mkOption {
      type = nullOr str;
      default = null;
      example = "0.0.0.0:4317";
      description = ''
        OTLP/gRPC endpoint to receive telemetry from other collectors, e.g.
        from `telemetry.opentelemetry.exporter.endpoints` on a remote machine.
      '';
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
      description = ''
        Write telemetry of the given signal to the collector's log at the
        verbosity the debug exporter is built with (for debugging the
        pipeline). Use sparingly, it can produce a lot of output.
      '';
    };
  };

  config = mkMerge [

    # enable opentelemetry collector
    # ------------------------------
    (mkIf (config.telemetry.enable && config.telemetry.pipelines.anyComplete) {
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

    # processors
    # -----------

    # metrics
    # add default tags processors
    # ---------------------------
    (mkIf (config.telemetry.enable && config.telemetry.pipelines.anyComplete) {

      services.opentelemetry-collector.settings = {

        processors = {

          # Fills unset resource `host.name` with this system's hostname
          # (`override = false`: existing values — e.g. a container's own
          # resource attributes forwarded over OTLP — are kept). Container
          # logs/metrics that arrive without a hostname therefore get
          # `networking.hostName` of the receiving host stamped on.
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
          "transform/service_name".log_statements = [
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

          # Hosts only (wired below): alloy promotes the journal's hostname
          # to the `host_name` log attribute, but the loki receiver delivers
          # labels as log attributes. Copy the per-record `host_name` onto
          # the resource as `host.name` (records without `host_name` — e.g.
          # OTLP-received logs that already carry the right resource — are
          # untouched). loki.nix promotes resource `host.name` to the
          # `host_name` index label.
          "transform/host_name".log_statements = [
            {
              context = "log";
              statements = [
                ''set(resource.attributes["host.name"], attributes["host_name"]) where attributes["host_name"] != nil''
              ];
            }
          ];

          # The loki receiver puts every stream of a push request under a single
          # ResourceLogs, so a resource attribute can only describe one service.
          # groupbyattrs splits the records back out: it moves the `service.name`
          # log attribute onto the Resource (one ResourceLogs per distinct
          # service) so each service gets its own stream in Loki.
          # https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/processor/groupbyattrsprocessor
          "groupbyattrs/service".keys = [ "service.name" ];

          # add-if-missing: stamp this host's hostname onto metric series
          # that don't carry one (container telemetry arrives with the
          # container's own host_name via telegraf global_tags)
          "metricstransform/host_name".transforms = [
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
        config.telemetry.enable
        && config.telemetry.pipelines.metrics.hasReceivers
        && config.telemetry.pipelines.metrics.hasExporters
      )
      {
        services.opentelemetry-collector.settings = {
          # both processors stamp this system's hostname onto metrics —
          # hosts only; a container's collector must not relabel container
          # telemetry with its own name (container identity arrives via
          # telegraf's global_tags instead).
          service.pipelines.metrics.processors = lib.optionals (!config.telemetry.isContainer) [
            "metricstransform/host_name"
            "resourcedetection/system"
          ];
        };
      }
    )
    # wire logs processors (only when both a source and sink exist, otherwise no pipeline)
    (mkIf
      (
        config.telemetry.enable
        && config.telemetry.pipelines.logs.hasReceivers
        && config.telemetry.pipelines.logs.hasExporters
      )
      {
        services.opentelemetry-collector.settings = {
          # hostname stamping is host-only and add-if-missing:
          # transform/host_name copies the per-record `host_name` attribute
          # (set by alloy on hosts); resourcedetection fills resource
          # `host.name` from networking.hostName when still unset
          # (override=false) — e.g. container logs, which carry only
          # container_name. A container's own collector must not stamp
          # anything. service_name grouping stays on everywhere — Loki
          # needs it for streams.
          service.pipelines.logs.processors =
            (lib.optionals (!config.telemetry.isContainer) [
              "transform/host_name"
              "resourcedetection/system"
            ])
            ++ [
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
        config.telemetry.opentelemetry.exporter.debug != null
        && config.telemetry.enable
        && config.telemetry.pipelines.${config.telemetry.opentelemetry.exporter.debug}.hasReceivers
      )
      {
        services.opentelemetry-collector.settings = {
          exporters.debug = {
            verbosity = "normal";
            sampling_initial = 5;
            sampling_thereafter = 200;
          };
          service.pipelines.${config.telemetry.opentelemetry.exporter.debug} = {
            exporters = [ "debug" ];
          };
        };
      }
    )

    # ship to downstream instances
    # ---------------------------
    (mkIf (config.telemetry.opentelemetry.exporter.endpoints != { } && config.telemetry.enable) {
      services.opentelemetry-collector.settings.exporters = mapAttrs' (name: endpoint: {
        name = "otlp/${name}";
        value = {
          endpoint = mkDefault endpoint;
          tls.insecure = mkDefault true;
        };
      }) config.telemetry.opentelemetry.exporter.endpoints;
    })
    (mkIf
      (
        config.telemetry.opentelemetry.exporter.endpoints != { }
        && config.telemetry.enable
        && config.telemetry.pipelines.logs.hasReceivers
      )
      {
        services.opentelemetry-collector.settings.service.pipelines.logs.exporters = map (
          name: "otlp/${name}"
        ) (attrNames config.telemetry.opentelemetry.exporter.endpoints);
      }
    )
    (mkIf
      (
        config.telemetry.opentelemetry.exporter.endpoints != { }
        && config.telemetry.enable
        && config.telemetry.pipelines.metrics.hasReceivers
      )
      {
        services.opentelemetry-collector.settings.service.pipelines.metrics.exporters = map (
          name: "otlp/${name}"
        ) (attrNames config.telemetry.opentelemetry.exporter.endpoints);
      }
    )

    # receive from other instances
    # ----------------------------
    (mkIf (config.telemetry.opentelemetry.receiver.endpoint != null && config.telemetry.enable) {
      services.opentelemetry-collector.settings.receivers.otlp.protocols.grpc.endpoint =
        config.telemetry.opentelemetry.receiver.endpoint;
    })
    (mkIf (
      config.telemetry.opentelemetry.receiver.endpoint != null
      && config.telemetry.enable
      && config.telemetry.pipelines.logs.hasExporters
    ) { services.opentelemetry-collector.settings.service.pipelines.logs.receivers = [ "otlp" ]; })
    (mkIf (
      config.telemetry.opentelemetry.receiver.endpoint != null
      && config.telemetry.enable
      && config.telemetry.pipelines.metrics.hasExporters
    ) { services.opentelemetry-collector.settings.service.pipelines.metrics.receivers = [ "otlp" ]; })

    # disable collector internal metrics
    # -----------------------------------
    (mkIf (config.telemetry.enable && config.telemetry.pipelines.anyComplete) {
      services.opentelemetry-collector.settings = {
        service.telemetry.metrics.level = "none";
      };
    })
  ];

}
