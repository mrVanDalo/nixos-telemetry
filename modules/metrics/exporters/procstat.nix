{
  pkgs,
  config,
  lib,
  ...
}:
with lib;
with types;
{
  options.telemetry.metrics.exporters.procstat.enable = mkOption {
    type = lib.types.bool;
    default = config.telemetry.metrics.enable;
  };

  config = mkMerge [

    (mkIf config.telemetry.metrics.exporters.procstat.enable {

      services.telegraf.extraConfig.inputs.procstat = {
        pattern = ".";
        #systemd_unit = ".*";
        #include_systemd_children = true;
      };

    })
  ];

}
