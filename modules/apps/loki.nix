{ config, lib, ... }:
let
  cfg = config.telemetry.apps.loki;
in
{
  options.telemetry.apps.loki = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Enable Loki as a log storage backend.
        When combined with `telemetry.apps.opentelemetry.enable`, logs
        collected by the OpenTelemetry collector are pushed to Loki.
      '';
    };

    port = lib.mkOption {
      type = lib.types.int;
      default = 3100;
      description = ''
        Port the Loki HTTP server listens on.
      '';
    };
  };

  config = lib.mkMerge [

    # enable loki service
    # -------------------
    (lib.mkIf cfg.enable {
      services.loki = {
        enable = lib.mkDefault true;
        configuration = {
          server.http_listen_port = cfg.port;

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
      (cfg.enable && config.telemetry.apps.opentelemetry.enable && config.telemetry.logs.hasSource)
      {
        services.opentelemetry-collector.settings = {
          exporters."otlphttp/loki" = {
            endpoint = "http://127.0.0.1:${toString cfg.port}/otlp";
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
