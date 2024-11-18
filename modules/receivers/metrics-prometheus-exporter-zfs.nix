{
  pkgs,
  config,
  lib,
  ...
}:
with lib;
with types;
{
  options.telemetry.prometheus.exporters.zfs.enable = mkOption {
    type = lib.types.bool;
    default = config.telemetry.metrics.enable;
  };

  config = mkMerge [

    (mkIf config.telemetry.prometheus.exporters.zfs.enable {

      # todo: prometheus or telegraf?
      services.telegraf.extraConfig.inputs.zfs = { };

      # Prometheus
      # ----------
      # fixme: this not working, because I get the same labels and values over and over again, which spams the logs.
      #services.prometheus.exporters.zfs.enable = true;

      # todo :  only when opentelemetry is enabled
      #services.opentelemetry-collector.settings = {
      #  receivers.prometheus.config.scrape_configs = [
      #    {
      #      job_name = "zfs";
      #      scrape_interval = "10s";
      #      static_configs = [
      #        {
      #          targets = [ "127.0.0.1:${toString config.services.prometheus.exporters.zfs.port}" ];
      #        }
      #      ];
      #    }
      #  ];
      #  service.pipelines.metrics.receivers = [ "prometheus" ];
      #};

    })
  ];

}
