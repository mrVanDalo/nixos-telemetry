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

          Netdata's prometheus endpoint is pull-only, so it only works where the
          collector can scrape it: normal machines and private-network nixos-containers.
          The `telemetry-container-shared-network` module therefore disables netdata
          with `lib.mkForce`; enabling it inside a shared-network container triggers a
          warning (its scrape port belongs to the host namespace and the host collector
          cannot scrape into the container).
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

    # warning: netdata in a shared-network container
    # ----------------------------------------------
    # netdata binds :19999 for its scrape endpoint; in a shared network
    # namespace that port belongs to the host (clash), and the host
    # collector cannot scrape into the container's netns anyway.
    (mkIf
      (
        config.telemetry.enable
        && config.telemetry.netdata.enable
        && config.telemetry.isSharedNetworkContainer
      )
      {
        warnings = [
          ''
            telemetry: netdata is enabled inside a shared-network container. 
            Netdata binds :19999 for scraping, which clashes with the host's
            network namespace, and its metrics cannot reach the host
            collector (pull-only endpoint). Disable telemetry.netdata or
            switch the container to privateNetwork.
          ''
        ];
      }
    )

    # configure netdata
    # -----------------
    (mkIf (config.telemetry.enable && config.telemetry.netdata.enable) {
      # https://docs.netdata.cloud/daemon/config/
      services.netdata = {
        enable = lib.mkDefault true;
        config = {
          global = {
            "memory mode" = "ram";
          };
        };
      };
    })

    # container identity as netdata host labels
    # -----------------------------------------
    # netdata host labels expose the container identity on the netdata
    # dashboard, API (`/api/v1/info`) and health entities. Note: the
    # allmetrics endpoint attaches them only to the `netdata_info`
    # metric, not to every metric — attaching the identity to every
    # scraped metric is the receiver's job (block below).
    (mkIf (config.telemetry.enable && config.telemetry.isContainer && config.telemetry.netdata.enable) {
      services.netdata.config."host labels" = mkIf config.telemetry.isContainer {
        container_name = config.networking.hostName;
        is_container = "true";
      };

    })

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
              # container identity as labels on the one scrape target: only private-network
              # containers (shared-network containers get a warning instead — their metrics
              # cannot reach the host collector, see the warning block above)
              static_configs = [
                (
                  {
                    targets = [ "127.0.0.1:${toString config.telemetry.ports.netdata}" ];
                  }
                  // (lib.optionalAttrs (config.telemetry.isContainer && !config.telemetry.isSharedNetworkContainer) {
                    labels = {
                      container_name = config.networking.hostName;
                      is_container = "true";
                    };
                  })
                )
              ];
            }
          ];
        };
      }
    )
  ];
}
