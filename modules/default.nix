{ lib, config, ... }:
with lib;
with types;
{

  options.telemetry = {
    enable = mkOption {
      type = bool;
      default = true;
      description = ''
        Convenience flag that enables various features, including metrics, logs, and OpenTelemetry shipping.
        These features can be enabled and disabled separately without using this flag.
      '';
    };
    metrics.enable = mkOption {
      type = bool;
      default = config.telemetry.enable;
    };
    logs.enable = mkOption {
      type = bool;
      default = config.telemetry.enable;
    };
  };

  imports = [

    ./opentelemetry.nix

    ./exporters
    ./receivers
  ];

  config = mkIf config.telemetry.enable { };

}
