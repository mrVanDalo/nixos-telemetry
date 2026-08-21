{
  config,
  lib,
  ...
}:
with lib;
with types;
{
  options.telemetry.metrics.exporters.zfs.enable = mkOption {
    type = lib.types.bool;
    default = config.telemetry.metrics.enable;
    description = ''
      Enable zfs metrics collection via telegraf.
    '';
  };

  config = mkMerge [

    (mkIf (config.telemetry.metrics.exporters.zfs.enable && config.telemetry.apps.telegraf.enable) {

      services.telegraf.extraConfig.inputs.zfs = {
        poolMetrics = lib.mkDefault true;
        datasetMetrics = lib.mkDefault true;
      };

    })
  ];

}
