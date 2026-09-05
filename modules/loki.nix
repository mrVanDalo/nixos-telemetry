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
          Enable Loki as a log storage backend.
          When combined with `telemetry.enable`, logs collected by the
          OpenTelemetry collector are pushed to Loki.
        '';
      };
      disk_full_threshold = lib.mkOption {
        type = lib.types.nullOr (lib.types.numbers.between 0 1);
        default = 0.9;
        example = 0.97;
        description = ''
          Fraction of disk usage (0.0–1.0) at which Loki's ingester WAL
          starts rejecting incoming log pushes (upstream default: 0.9).
          When the disk holding /var/lib/loki is at or above this fraction,
          every push fails with HTTP 503 and the misleading error
          `Ingester is shutting down`; the OpenTelemetry collector then
          fills its sending queue and drops logs. Crossing the threshold is
          logged once by Loki (`disk usage exceeded threshold, throttling
          writes`), and the current usage is exposed as the metric
          `loki_ingester_wal_diskusage_percent`.

          Setting this to `null` disables the threshold entirely, so Loki
          keeps accepting pushes regardless of disk usage. On a truly full
          disk WAL writes can then fail and data can be lost — prefer
          freeing space, or set a high value (e.g. `0.97`) if the disk
          should stay protected.
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

          # `null` disables the WAL disk-usage throttle (0); anything else
          # is the usage fraction at which Loki rejects log pushes with a
          # misleading `Ingester is shutting down` 503.
          ingester.wal.disk_full_threshold =
            if cfg.disk_full_threshold == null then 0 else cfg.disk_full_threshold;

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
    (lib.mkIf (config.telemetry.enable && cfg.enable && config.telemetry.pipelines.logs.hasSource) {
      services.opentelemetry-collector.settings = {
        exporters."otlphttp/loki" = {
          endpoint = "http://127.0.0.1:${toString config.telemetry.ports.loki}/otlp";
        };
        service.pipelines.logs.exporters = [ "otlphttp/loki" ];
      };

      # start the collector after loki so its first export doesn't hit
      # "connection refused" while loki is still coming up
      systemd.services.opentelemetry-collector.after = [ "loki.service" ];
    })

  ];
}
