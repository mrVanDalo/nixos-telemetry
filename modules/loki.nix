{ config, lib, ... }:
let
  cfg = config.telemetry.loki;
in
{
  options = {
    telemetry.loki = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Convenience option that enables `services.loki.enable` with opinionated
          defaults and wires it as a log sink into the OpenTelemetry collector. 

          Even without this flag, if `services.loki.enable = true` is set directly,
          the collector pushes logs to Loki automatically.
        '';
      };
    };
    telemetry.ports.loki = lib.mkOption {
      type = lib.types.int;
      default = 3100;
      description = ''
        Port the Loki HTTP server listens on.
        The OpenTelemetry collector sends logs to this port.
      '';
    };
  };

  config = lib.mkMerge [

    # enable loki service
    # -------------------
    (lib.mkIf (config.telemetry.enable && cfg.enable) {
      services.loki = {
        enable = lib.mkDefault true;
        configuration = {
          server.http_listen_port = config.telemetry.ports.loki;

          auth_enabled = false;

          common = {
            ring.instance_addr = "127.0.0.1";
            ring.kvstore.store = "inmemory";
            replication_factor = 1;
            path_prefix = "/var/lib/loki";
          };

          schema_config = {
            configs = [
              {
                from = "2024-01-01";
                store = "tsdb";
                object_store = "filesystem";
                schema = "v13";
                index = {
                  prefix = "index_";
                  period = "24h";
                };
              }
            ];
          };

          storage_config = {
            filesystem.directory = "/var/lib/loki/chunks";
            tsdb_shipper = {
              active_index_directory = "/var/lib/loki/tsdb-index";
              cache_location = "/var/lib/loki/tsdb-cache";
            };
          };

          limits_config = {
            retention_period = "30d";
            reject_old_samples = true;
            reject_old_samples_max_age = "168h";
            # When logs arrive via OTLP (the opentelemetry collector's
            # otlphttp/loki exporter), Loki only promotes a curated default
            # set of resource attributes to stream labels — host.name is not
            # among them. The resourcedetection processor sets host.name as a
            # resource attribute so logs can be selected by host; promote it
            # to an index label (host.name → host_name) so that actually works.
            otlp_config.resource_attributes.attributes_config = [
              {
                action = "index_label";
                attributes = [ "host.name" ];
              }
            ];
          };

          compactor = {
            working_directory = "/var/lib/loki/compactor";
            compaction_interval = "10m";
            retention_enabled = true;
            retention_delete_delay = "2h";
            retention_delete_worker_count = 150;
            delete_request_store = "filesystem";
          };
        };
      };
    })

    # wire opentelemetry collector → loki (via OTLP HTTP, loki exporter was removed in otel 0.155+)
    # --------------------------------------------------------------
    (lib.mkIf
      (
        config.telemetry.enable
        && config.services.loki.enable
        && config.telemetry.pipelines.logs.hasReceiver
      )
      {
        services.opentelemetry-collector.settings = {
          exporters."otlphttp/loki" = {
            endpoint = "http://127.0.0.1:${toString config.services.loki.configuration.server.http_listen_port}/otlp";
          };
          service.pipelines.logs.exporters = [ "otlphttp/loki" ];
        };

        # start the collector after loki so its first export doesn't hit
        # "connection refused" while loki is still coming up
        systemd.services.opentelemetry-collector.after = [ "loki.service" ];
      }
    )

  ];
}
