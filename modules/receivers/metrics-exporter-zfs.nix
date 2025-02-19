{
  pkgs,
  config,
  lib,
  ...
}:
with lib;
with types;
{
  options.telemetry.exporters.zfs.enable = mkOption {
    type = lib.types.bool;
    default = config.telemetry.metrics.enable;
    description = "todo";
  };

  config = mkMerge [

    (mkIf config.telemetry.exporters.zfs.enable {

      # todo: prometheus or telegraf?
      services.telegraf.extraConfig.inputs.zfs = {
        poolMetrics = lib.mkDefault true;
        datasetMetrics = lib.mkDefault true;
      };

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
