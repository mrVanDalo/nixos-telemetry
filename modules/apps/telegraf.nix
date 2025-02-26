{
  config,
  pkgs,
  lib,
  ...
}:
with lib;
with types;
let
  cfg = config.telemetry.apps.telegraf;
in
{
  options.telemetry.apps.telegraf = {
    enable = mkOption {
      type = lib.types.bool;
      default = config.telemetry.metrics.enable;
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
  };

  config = lib.mkMerge [

    # wire telegraf with opentelemetry
    # -------------------------------
    (mkIf (config.telemetry.apps.telegraf.enable && config.telemetry.apps.opentelemetry.enable) {

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
    (mkIf (config.telemetry.apps.telegraf.enable) {

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
            # todo : this is a presonal configuration, and go
            ping = [ { urls = [ "10.100.0.1" ]; } ]; # actually important to make machine visible over wireguard

            # services
            # todo : add all kinds of services here
            #docker = (lib.mkIf config.components.virtualisation.docker.enable (lib.mkDefault {}));
          };
        };
      };
    })
  ];
}
