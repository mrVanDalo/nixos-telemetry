{ lib, config, ... }:
with lib;
with types;
{
  options.telemetry = {
    enable = mkOption {
      type = bool;
      default = false;
      description = ''
        Whether to enable the NixOS telemetry system.
        This is the main switch that orchestrates all telemetry functionality:
        it dynamically starts the OpenTelemetry collector when a complete pipeline
        exists — a source and sink for the same signal type are both active.

        Services are auto-wired with the collector when enabled, whether you use the
        convenience option `telemetry.<app>.enable` or set `services.<app>.enable = true`
        directly. The collector configuration is injected into each enabled service.
      '';
    };

    # internal: whether the metrics/logs pipeline will have both a source and a sink.
    # pipeline fragments (receivers/exporters/processors) are only created when both exist,
    # so the OTel collector never sees a pipeline with missing receivers or exporters.
    pipelines.metrics.hasReceiver = mkOption {
      type = bool;
      readOnly = true;
      internal = true;
      description = "Internal: at least one metrics receiver is configured.";
    };
    pipelines.metrics.hasExporter = mkOption {
      type = bool;
      readOnly = true;
      internal = true;
      description = "Internal: at least one metrics exporter is configured.";
    };
    pipelines.logs.hasReceiver = mkOption {
      type = bool;
      readOnly = true;
      internal = true;
      description = "Internal: at least one logs receiver is configured.";
    };
    pipelines.logs.hasExporter = mkOption {
      type = bool;
      readOnly = true;
      internal = true;
      description = "Internal: at least one logs exporter is configured.";
    };
    pipelines.anyComplete = mkOption {
      type = bool;
      readOnly = true;
      internal = true;
      description = "Internal: at least one complete pipeline (a metrics or logs source+sink pair) exists, so the collector can start.";
    };
  };

  imports = [
    ./opentelemetry.nix
    ./alloy.nix
    ./loki.nix
    ./telegraf.nix
    ./prometheus.nix
    ./netdata.nix
    ./grafana.nix
    ./renamed.nix
  ];

  config = {
    # .receiver.endpoints!= null is not a good test, but don't know any better one yet
    telemetry.pipelines.metrics.hasReceiver =
      config.services.telegraf.enable
      || config.services.netdata.enable
      || (config.telemetry.opentelemetry.receiver.endpoint != null);

    # .exporter.endpoints != null is not a good test, but don't know any better one yet
    telemetry.pipelines.metrics.hasExporter =
      config.services.prometheus.enable
      || (config.telemetry.opentelemetry.exporter.endpoints != { })
      || (config.telemetry.opentelemetry.exporter.debug == "metrics");

    # .receiver.endponit != null is not a good test, but don't know any better one yet
    telemetry.pipelines.logs.hasReceiver =
      config.services.alloy.enable || (config.telemetry.opentelemetry.receiver.endpoint != null);

    # .exporter.endpoints != null is not a good test, but don't know any better one yet
    telemetry.pipelines.logs.hasExporter =
      config.services.loki.enable
      || (config.telemetry.opentelemetry.exporter.endpoints != { })
      || (config.telemetry.opentelemetry.exporter.debug == "logs");

    telemetry.pipelines.anyComplete =
      (config.telemetry.pipelines.metrics.hasReceiver && config.telemetry.pipelines.metrics.hasExporter)
      || (config.telemetry.pipelines.logs.hasReceiver && config.telemetry.pipelines.logs.hasExporter);
  };
}
