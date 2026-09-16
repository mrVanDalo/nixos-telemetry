{
  lib,
  config,
  ...
}:
with lib;
with types;
{
  options = {
    telemetry.netdata = {
      enable = mkOption {
        type = bool;
        default = false;
        description = ''
          Whether to start netdata to collect metrics.

          Netdata is only started on normal machines and on private-network
          nixos-containers. It is force-disabled inside sharedNetworkContainer,
          because it opens a port for scraping there -> port clashes, and its
          metrics cannot reach the host collector.
        '';

      };
    };
    telemetry.ports.netdata = mkOption {
      type = int;
      default = 19999;
      description = ''
        Port netdata exposes its metrics on.
        The OpenTelemetry collector scrapes metrics from this port.
      '';
    };
  };

  config = mkMerge [

    # configure netdata
    # -----------------
    (mkIf
      (
        config.telemetry.enable
        && config.telemetry.netdata.enable
        # We don't start netdata in a sharedNetworkContainer, because it opens a port for scraping
        # -> port clashes
        && !config.telemetry.isSharedNetworkContainer
      )
      {
        # https://docs.netdata.cloud/daemon/config/
        services.netdata = {
          enable = lib.mkDefault true;
          config = {
            global = {
              "memory mode" = "ram";
            };
          };
        };
      }
    )

    # container identity on every scraped netdata metric
    # -------------------------------------------------
    # netdata's prometheus endpoint cannot add per-metric host labels, so
    # when this (netdata-enabled) host is a container the collector's
    # scrape attaches the identity to all metrics of the job. In
    # shared-network containers netdata itself is force-disabled (its
    # metrics cannot reach the host collector), so this only fires for
    # private-network containers with their own collector.
    (mkIf
      (
        config.telemetry.enable
        && config.telemetry.isContainer
        && !config.telemetry.isSharedNetworkContainer
        && config.telemetry.netdata.enable
        && config.telemetry.pipelines.metrics.hasExporters
      )
      {
        # container identity as netdata host labels: visible on the dashboard,
        # API (`/api/v1/info`) and health entities. Note: the allmetrics
        # endpoint attaches these only to the `netdata_info` metric, not to
        # every metric — the receiver-side labels below do that job.
        services.netdata.config."host labels" = mkIf config.telemetry.isContainer {
          container_name = config.networking.hostName;
          is_container = "true";
        };

        services.opentelemetry-collector.settings.receivers."prometheus/netdata".config.scrape_configs =
          mkAfter
            [
              {
                job_name = "netdata";
                static_configs.labels = {
                  container_name = config.networking.hostName;
                  is_container = "true";
                };
              }
            ]
            config.services.opentelemetry-collector.settings.receivers."prometheus/netdata".config.scrape_configs;
      }
    )

    # wire netdata with opentelemetry
    # -------------------------------
    (mkIf
      (
        config.telemetry.enable
        && config.telemetry.netdata.enable
        && config.telemetry.pipelines.metrics.hasExporters
      )
      {
        services.opentelemetry-collector.settings = {

          service.pipelines.metrics.receivers = [ "prometheus/netdata" ];

          receivers."prometheus/netdata".config.scrape_configs = [
            {
              job_name = "netdata";
              scrape_interval = "10s";
              metrics_path = "/api/v1/allmetrics";
              params.format = [ "prometheus" ];
              static_configs = [ { targets = [ "127.0.0.1:${toString config.telemetry.ports.netdata}" ]; } ];
            }
          ];
        };
      }
    )
  ];
}
