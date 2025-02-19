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
      default = config.telemetry.metrics.enable;
      description = "todo";
    };
    influxDBPort = mkOption {
      type = int;
      default = 8088;
      description = "Port to listen on influxDB input";
    };
  };

  config = lib.mkMerge [
    (mkIf config.telemetry.telegraf.enable {
      # opentelemetry wireing
      services.opentelemetry-collector.settings = {
        receivers.influxdb.endpoint = "127.0.0.1:${toString cfg.influxDBPort}";
        service.pipelines.metrics.receivers = [ "influxdb" ];
      };
      services.telegraf.extraConfig.outputs.influxdb_v2.urls = [
        "http://127.0.0.1:${toString cfg.influxDBPort}"
      ];
    })

    (mkIf config.telemetry.telegraf.enable {

      systemd.services.telegraf.path = [ pkgs.inetutils ];

      services.telegraf = {
        enable = true;
        extraConfig = {
          # https://github.com/influxdata/telegraf/tree/master/plugins/inputs < all them plugins
          inputs = {
            cpu = { };
            diskio = { };
            disk = { };
            processes = { };
            system = { };
            systemd_units = { };
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
