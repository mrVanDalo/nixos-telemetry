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
        This is the main switch that controls all telemetry functionality.
      '';
    };
    metrics.enable = mkOption {
      type = bool;
      default = config.telemetry.enable;
      description = ''
        Controls the collection of system metrics.
        When enabled, nixos-telemetry will collect metrics from configured
        services that are enabled in your NixOS configuration.
      '';
    };
    logs.enable = mkOption {
      type = bool;
      default = config.telemetry.enable;
      description = ''
        Controls the collection of system logs.
        When enabled, nixos-telemetry will collect logs from configured
        services that are enabled in your NixOS configuration.
      '';
    };

    # internal: whether the metrics/logs pipeline will have both a source and a sink.
    # pipeline fragments (receivers/exporters/processors) are only created when both exist,
    # so the OTel collector never sees a pipeline with missing receivers or exporters.
    metrics.hasSource = mkOption {
      type = bool;
      readOnly = true;
      internal = true;
      description = "Internal: at least one metrics source (receiver) is configured.";
    };
    metrics.hasSink = mkOption {
      type = bool;
      readOnly = true;
      internal = true;
      description = "Internal: at least one metrics sink (exporter) is configured.";
    };
    logs.hasSource = mkOption {
      type = bool;
      readOnly = true;
      internal = true;
      description = "Internal: at least one logs source (receiver) is configured.";
    };
    logs.hasSink = mkOption {
      type = bool;
      readOnly = true;
      internal = true;
      description = "Internal: at least one logs sink (exporter) is configured.";
    };
  };

  imports = [
    ./metrics
    ./apps
    ./logs
  ];

  config = {
    telemetry.metrics.hasSource =
      config.telemetry.apps.telegraf.enable
      || config.telemetry.apps.netdata.enable
      || (config.telemetry.apps.opentelemetry.receiver.endpoint != null);

    telemetry.metrics.hasSink =
      config.telemetry.apps.prometheus.enable
      || (config.telemetry.apps.opentelemetry.exporter.endpoints != { })
      || (config.telemetry.apps.opentelemetry.exporter.debug == "metrics");

    telemetry.logs.hasSource =
      config.telemetry.apps.alloy.enable
      || (config.telemetry.apps.opentelemetry.receiver.endpoint != null);

    telemetry.logs.hasSink =
      config.telemetry.apps.loki.enable
      || (config.telemetry.apps.opentelemetry.exporter.endpoints != { })
      || (config.telemetry.apps.opentelemetry.exporter.debug == "logs");
  };
}
