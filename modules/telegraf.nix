{
  config,
  pkgs,
  lib,
  ...
}:
with lib;
with types;
let
  cfg = config.telemetry.telegraf;
in
{
  options.telemetry.telegraf = {
    enable = mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        enable telegraf to collect metrics.
      '';
    };
    port = mkOption {
      type = int;
      default = 8088;
      description = ''
        influxdb port opened by opentelemetry collector which telemetry will send metrics to.
      '';
    };
    inputs.procstat.enable = mkOption {
      type = bool;
      default = false;
      description = ''
        Enable process statistics metrics collection via telegraf.
      '';
    };
    inputs.zfs.enable = mkOption {
      type = bool;
      default = false;
      description = ''
        Enable zfs metrics collection via telegraf.
      '';
    };
  };

  config = lib.mkMerge [

    # wire telegraf with opentelemetry
    # -------------------------------
    (mkIf (config.telemetry.enable && cfg.enable && config.telemetry.pipelines.metrics.hasSink) {

      # opentelemetry wireing
      services.opentelemetry-collector.settings = {
        receivers.influxdb.endpoint = "127.0.0.1:${toString cfg.port}";
        service.pipelines.metrics.receivers = [ "influxdb" ];
      };

      services.telegraf.extraConfig.outputs.influxdb_v2.urls = [
        "http://127.0.0.1:${toString cfg.port}"
      ];

    })

    # configure telegraf
    # -----------------
    (mkIf (config.telemetry.enable && cfg.enable) {

      systemd.services.telegraf.path = [ pkgs.inetutils ];

      services.telegraf = {
        enable = mkDefault true;
        extraConfig = {
          global_tags = {
            instance_name = config.networking.hostName; # this will end up as `instance` label  in  prometheus
          };
          # https://github.com/influxdata/telegraf/tree/master/plugins/inputs < all them plugins
          inputs = {

            # todo : put this in under `metrics.exporters.*`
            cpu = { };
            diskio = { };
            disk = { };
            processes = { };
            system = { };
            systemd_units = { };
            temp = { };

            # services
            # todo : add all kinds of services here
            #docker = (lib.mkIf config.components.virtualisation.docker.enable (lib.mkDefault {}));
          };
        };
      };
    })

    # process statistics metrics collection
    # --------------------------------------
    (mkIf (config.telemetry.enable && cfg.enable && cfg.inputs.procstat.enable) {
      services.telegraf.extraConfig.inputs.procstat.pattern = ".";
    })

    # zfs metrics collection
    # -----------------------
    (mkIf (config.telemetry.enable && cfg.enable && cfg.inputs.zfs.enable) {
      services.telegraf.extraConfig.inputs.zfs = {
        poolMetrics = mkDefault true;
        datasetMetrics = mkDefault true;
      };
    })
  ];
}
