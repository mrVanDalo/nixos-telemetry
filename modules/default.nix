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
        it starts the OpenTelemetry collector when a complete pipeline exists,
        and apps are individually opt-in (`telemetry.<app>.enable`).
      '';
    };

    autowire.enable = mkOption {
      type = bool;
      default = true;
      description = ''
        Master switch for automatically wiring telemetry collection
        for services detected on the machine (e.g. nginx, mysql, docker).
        Can be overridden per collector and per app,
        e.g. `telemetry.telegraf.autowire.mysql.enable`.
      '';
    };

    # internal: whether the metrics/logs pipeline will have both a source and a sink.
    # pipeline fragments (receivers/exporters/processors) are only created when both exist,
    # so the OTel collector never sees a pipeline with missing receivers or exporters.
    pipelines.metrics.hasSource = mkOption {
      type = bool;
      readOnly = true;
      internal = true;
      description = "Internal: at least one metrics source (receiver) is configured.";
    };
    pipelines.metrics.hasSink = mkOption {
      type = bool;
      readOnly = true;
      internal = true;
      description = "Internal: at least one metrics sink (exporter) is configured.";
    };
    pipelines.logs.hasSource = mkOption {
      type = bool;
      readOnly = true;
      internal = true;
      description = "Internal: at least one logs source (receiver) is configured.";
    };
    pipelines.logs.hasSink = mkOption {
      type = bool;
      readOnly = true;
      internal = true;
      description = "Internal: at least one logs sink (exporter) is configured.";
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
    ./ports.nix
    ./grafana.nix
    ./renamed.nix
  ];

  config = {
    telemetry.pipelines.metrics.hasSource =
      config.telemetry.telegraf.enable
      || config.telemetry.netdata.enable
      || (config.telemetry.opentelemetry.receiver.endpoint != null);

    telemetry.pipelines.metrics.hasSink =
      config.telemetry.prometheus.enable
      || (config.telemetry.opentelemetry.exporter.endpoints != { })
      || (config.telemetry.opentelemetry.exporter.debug == "metrics");

    telemetry.pipelines.logs.hasSource =
      config.telemetry.alloy.enable || (config.telemetry.opentelemetry.receiver.endpoint != null);

    telemetry.pipelines.logs.hasSink =
      config.telemetry.loki.enable
      || (config.telemetry.opentelemetry.exporter.endpoints != { })
      || (config.telemetry.opentelemetry.exporter.debug == "logs");

    telemetry.pipelines.anyComplete =
      (config.telemetry.pipelines.metrics.hasSource && config.telemetry.pipelines.metrics.hasSink)
      || (config.telemetry.pipelines.logs.hasSource && config.telemetry.pipelines.logs.hasSink);
  };
}
