# Vector (https://vector.dev) collector app.
#
# Vector replaces `telemetry.alloy` + `telemetry.telegraf` with a single
# binary: it reads journald and host metrics locally and ships both to the
# central OpenTelemetry collector via OTLP/HTTP. The only listener involved
# is the OpenTelemetry collector's own OTLP/HTTP receiver, so this module
# opens no port of its own.
#
# The `opentelemetry` sink wraps the `http` sink and renders its `uri`
# template per event with no per-signal path rewriting (src/sinks/opentelemetry/
# mod.rs, sinks/http/sink.rs in Vector v0.58), and with `encoding.codec = otlp`
# each event must already carry the OTLP JSON top-level field the serializer
# dispatches on (`resourceLogs` -> ExportLogsServiceRequest, else the encoder
# rejects the event). Journald logs are therefore wrapped into the OTLP JSON
# envelope by a remap transform; host metrics are native `Event::Metric`s that
# the serializer converts to `ExportMetricsServiceRequest` on their own sink
# pointed at `/v1/metrics`.
{
  config,
  lib,
  ...
}:
let
  cfg = config.telemetry.vector;

  vectorEnabled = config.telemetry.enable && cfg.enable;
in
{
  options = {
    telemetry.vector = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          enable vector to collect journald logs and host metrics.
          Vector pushes both into the central OpenTelemetry collector
          (OTLP/HTTP), replacing `telemetry.alloy` and `telemetry.telegraf`
          for log and host-metric collection.
        '';
      };
    };
  };

  config = lib.mkMerge [

    # opentelemetry shipment
    # ----------------------
    # Register the collector's OTLP/HTTP receiver and add it to the pipelines
    # whose signals Vector supplies. The receiver is always appended: when
    # `telemetry.opentelemetry.receiver.endpoint` is set, `opentelemetry.nix`
    # registers the same receiver (grpc protocol only), and the collector
    # tolerates duplicate names in a pipeline's receiver list.
    (lib.mkIf (vectorEnabled && config.telemetry.pipelines.logs.hasSink) {
      services.opentelemetry-collector.settings = {
        receivers.otlp.protocols.http.endpoint = "127.0.0.1:4318";
        service.pipelines.logs.receivers = [ "otlp" ];
      };
    })

    (lib.mkIf (vectorEnabled && config.telemetry.pipelines.metrics.hasSink) {
      services.opentelemetry-collector.settings = {
        receivers.otlp.protocols.http.endpoint = "127.0.0.1:4318";
        service.pipelines.metrics.receivers = [ "otlp" ];
      };
    })

    # vector configuration
    # --------------------
    # Each Vector component is gated on the matching pipeline sink: the
    # collector's OTLP receiver only serves signals that have a pipeline,
    # so sending an unsunk signal would 404 and drop events.
    (lib.mkIf (vectorEnabled && config.telemetry.pipelines.logs.hasSink) {
      services.vector.enable = lib.mkDefault true;
      services.vector.journaldAccess = lib.mkDefault true;
      services.vector.settings = {
        sources.journald.type = "journald";
        # Wrap journald log events into the OTLP JSON envelope the
        # `otlp` codec dispatches on (`resourceLogs` top-level field,
        # lowerCamelCase proto3 JSON names).
        #
        # In Vector's default (legacy) log namespace the journald source
        # flattens journal fields onto the event: the message lands in
        # `.message` (MESSAGE is removed), `PRIORITY` stays as a string,
        # and the realtime timestamp becomes `.timestamp`. Remaining
        # journal fields (including `_SYSTEMD_UNIT`) stay on the event.
        # We map them to OTLP positions:
        #   - `_SYSTEMD_UNIT` -> log record attribute `unit` and the
        #     resource `service.name`, so the collector's
        #     `transform/service_name` processor can promote it exactly
        #     like alloy's relabel rules do.
        #   - `PRIORITY` -> `severityNumber` (syslog 0..7 equals OTLP
        #     SeverityNumber 1..8, hence +1) and `severityText`.
        # All other journal fields travel as log record attributes.
        transforms.enrich_journald = {
          type = "remap";
          inputs = [ "journald" ];
          source = ''
            pri = to_int(del(.PRIORITY)) ?? 6
            unit = del(._SYSTEMD_UNIT)
            host_name = del(._HOSTNAME)
            transport = del(._TRANSPORT)
            boot_id = del(._BOOT_ID)
            msg = to_string(del(.message)) ?? ""
            service = if unit == "" { "vector" } else { unit }

            # the unit attribute drives the collector's
            # `transform/service_name` processor; the labels below match
            # what alloy's journal relabel rules produce; every remaining
            # journal field travels as a string attribute
            entries = [
              { "key": "unit", "value": { "stringValue": unit } },
              { "key": "host_name", "value": { "stringValue": host_name } },
              { "key": "transport", "value": { "stringValue": transport } },
              { "key": "boot_id", "value": { "stringValue": boot_id } },
            ]
            for_each(del(.)) -> |k, v| {
              s = to_string(v) ?? ""
              entries = push(entries, { "key": k, "value": { "stringValue": s } })
            }

            severity, level = to_syslog_level(pri)

            .resourceLogs = [{
              "resource": {
                "attributes": [
                  { "key": "service.name", "value": { "stringValue": service } }
                ]
              },
              "scopeLogs": [{
                "logRecords": [{
                  "timeUnixNano": to_unix_timestamp(now(), unit: "nanoseconds"),
                  "severityNumber": pri + 1,
                  "severityText": level,
                  "body": { "stringValue": msg },
                  "attributes": entries
                }]
              }]
            }]
          '';
        };
        sinks.otel_logs = {
          type = "opentelemetry";
          inputs = [ "enrich_journald" ];
          protocol = {
            type = "http";
            # OTLP/HTTP receiver of the central OpenTelemetry collector.
            uri = "http://127.0.0.1:4318/v1/logs";
            encoding.codec = "otlp";
          };
        };
      };
    })

    (lib.mkIf (vectorEnabled && config.telemetry.pipelines.metrics.hasSink) {
      services.vector.enable = lib.mkDefault true;
      services.vector.settings = {
        # `host` is the source's own default namespace; spelled out so the
        # emitted metric names are stable across upstream default changes.
        sources.host_metrics = {
          type = "host_metrics";
          namespace = "host";
          scrape_interval_secs = 15;
        };
        sinks.otel_metrics = {
          type = "opentelemetry";
          inputs = [ "host_metrics" ];
          protocol = {
            type = "http";
            uri = "http://127.0.0.1:4318/v1/metrics";
            encoding.codec = "otlp";
          };
        };
      };
    })
  ];
}
