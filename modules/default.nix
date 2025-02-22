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
  };

  imports = [
    ./metrics
    ./apps
    ./logs
  ];

  config = mkIf config.telemetry.enable { };
}
