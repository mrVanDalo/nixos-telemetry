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
  options = {
    telemetry.telegraf = {
      enable = mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Convenience option that enables `services.telegraf.enable` with opinionated
          defaults and wires it as a metrics source into the OpenTelemetry collector.

          Even without this flag, if `services.telegraf.enable = true` is set directly,
          the OTel wiring still happens automatically.
        '';
      };
      inputs.procstat.pattern = mkOption {
        type = nullOr str;
        default = null;
        description = ''
          Process name pattern to collect metrics from (e.g. "nginx", "java", "." for all).
          Passed directly to telegraf's procstat input `pattern` option.
          This is intentionally not auto-detected because collecting metrics
          for every running process can heavily pollute the metrics output.
        '';
      };
    };
    telemetry.ports.telegraf = mkOption {
      type = int;
      default = 8088;
      description = ''
        InfluxDB receiver port opened by the OpenTelemetry collector.
        Telegraf sends metrics to this port.
      '';
    };
  };

  config = lib.mkMerge [

    # wire telegraf with opentelemetry
    # -------------------------------
    (mkIf
      (
        config.telemetry.enable
        && config.services.telegraf.enable
        && config.telemetry.pipelines.metrics.hasExporter
      )
      {

        services.opentelemetry-collector.settings = {
          service.pipelines.metrics.receivers = [ "influxdb" ];
          receivers.influxdb = {
            endpoint = "127.0.0.1:${toString config.telemetry.ports.telegraf}";
          };
        };

        services.telegraf.extraConfig.outputs.influxdb_v2.urls = [
          "http://127.0.0.1:${toString config.telemetry.ports.telegraf}"
        ];

      }
    )

    # configure telegraf
    # -----------------
    (mkIf (config.telemetry.enable && cfg.enable) {

      systemd.services.telegraf.path = [ pkgs.inetutils ];

      services.telegraf = {
        enable = true;
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
            mem = { };

            # services
            # todo : add all kinds of services here
            #docker = (lib.mkIf config.components.virtualisation.docker.enable (lib.mkDefault {}));
          };
        };
      };
    })

    # zfs metrics collection
    # -----------------------
    (mkIf (config.telemetry.enable && config.boot.zfs.enabled && config.services.telegraf.enable) {
      services.telegraf.extraConfig.inputs.zfs = {
        poolMetrics = true;
        datasetMetrics = true;
      };
    })

    # process statistics metrics collection
    # --------------------------------------
    (mkIf (config.telemetry.enable && cfg.enable && cfg.inputs.procstat.pattern != null) {
      services.telegraf.extraConfig.inputs.procstat.pattern = cfg.inputs.procstat.pattern;
    })

  ];
}
