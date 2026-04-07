{ config, lib, ... }:
let
  cfg = config.telemetry.apps.alloy;
in
{
  options.telemetry.apps.alloy = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = config.telemetry.logs.enable;
      description = ''
        Enable grafana-alloy to scrape journal logs.
        This is the replacement for promtail which reached end of life.
      '';
    };
    port = lib.mkOption {
      type = lib.types.int;
      default = 3500;
      description = ''
        Port of the local Loki-compatible receiver.
        This is the port alloy will send logs to.
      '';
    };
  };

  config = lib.mkMerge [

    # opentelemetry shipment
    # -----------------------
    (lib.mkIf (cfg.enable && config.telemetry.apps.opentelemetry.enable) {
      services.opentelemetry-collector.settings = {

        service.pipelines.logs.receivers = [ "loki" ];

        receivers.loki = {
          protocols.http.endpoint = "127.0.0.1:${toString cfg.port}";
          use_incoming_timestamp = true;
        };

      };

    })

    # alloy configuration
    # --------------------
    (lib.mkIf cfg.enable {

      services.alloy.enable = lib.mkDefault true;

      environment.etc."alloy/journal.alloy".text = ''
        loki.relabel "journal" {
          forward_to = []

          // unit: prefer _SYSTEMD_UNIT, fall back to _TRANSPORT
          rule {
            source_labels = ["__journal__systemd_unit"]
            target_label  = "unit"
          }
          rule {
            source_labels = ["unit", "__journal__transport"]
            separator     = ";"
            regex         = "^;(.+)$"
            target_label  = "unit"
            replacement   = "$1"
          }

          // normalize session-NNNN.scope -> session.scope
          rule {
            source_labels = ["unit"]
            regex         = "session-\\d+\\.scope"
            target_label  = "unit"
            replacement   = "session.scope"
          }

          rule {
            source_labels = ["__journal__hostname"]
            target_label  = "instance_name"
          }
          rule {
            source_labels = ["__journal__transport"]
            target_label  = "transport"
          }
          rule {
            source_labels = ["__journal__boot_id"]
            target_label  = "boot_id"
          }

          // priority (numeric)
          rule {
            source_labels = ["__journal_priority"]
            target_label  = "priority"
          }

          // priority_label (human readable, matching promtail naming)
          rule {
            source_labels = ["__journal_priority"]
            regex         = "^0$"
            target_label  = "priority_label"
            replacement   = "emergency"
          }
          rule {
            source_labels = ["__journal_priority"]
            regex         = "^1$"
            target_label  = "priority_label"
            replacement   = "alert"
          }
          rule {
            source_labels = ["__journal_priority"]
            regex         = "^2$"
            target_label  = "priority_label"
            replacement   = "critical"
          }
          rule {
            source_labels = ["__journal_priority"]
            regex         = "^3$"
            target_label  = "priority_label"
            replacement   = "error"
          }
          rule {
            source_labels = ["__journal_priority"]
            regex         = "^4$"
            target_label  = "priority_label"
            replacement   = "warning"
          }
          rule {
            source_labels = ["__journal_priority"]
            regex         = "^5$"
            target_label  = "priority_label"
            replacement   = "notice"
          }
          rule {
            source_labels = ["__journal_priority"]
            regex         = "^6$"
            target_label  = "priority_label"
            replacement   = "info"
          }
          rule {
            source_labels = ["__journal_priority"]
            regex         = "^7$"
            target_label  = "priority_label"
            replacement   = "debug"
          }

          // facility (numeric)
          rule {
            source_labels = ["__journal_syslog_facility"]
            target_label  = "facility"
          }

          // facility_label (human readable, matching promtail naming)
          rule {
            source_labels = ["__journal_syslog_facility"]
            regex         = "^0$"
            target_label  = "facility_label"
            replacement   = "kern"
          }
          rule {
            source_labels = ["__journal_syslog_facility"]
            regex         = "^1$"
            target_label  = "facility_label"
            replacement   = "user"
          }
          rule {
            source_labels = ["__journal_syslog_facility"]
            regex         = "^2$"
            target_label  = "facility_label"
            replacement   = "mail"
          }
          rule {
            source_labels = ["__journal_syslog_facility"]
            regex         = "^3$"
            target_label  = "facility_label"
            replacement   = "daemon"
          }
          rule {
            source_labels = ["__journal_syslog_facility"]
            regex         = "^4$"
            target_label  = "facility_label"
            replacement   = "auth"
          }
          rule {
            source_labels = ["__journal_syslog_facility"]
            regex         = "^5$"
            target_label  = "facility_label"
            replacement   = "syslog"
          }
          rule {
            source_labels = ["__journal_syslog_facility"]
            regex         = "^6$"
            target_label  = "facility_label"
            replacement   = "lpr"
          }
          rule {
            source_labels = ["__journal_syslog_facility"]
            regex         = "^7$"
            target_label  = "facility_label"
            replacement   = "news"
          }
          rule {
            source_labels = ["__journal_syslog_facility"]
            regex         = "^8$"
            target_label  = "facility_label"
            replacement   = "uucp"
          }
          rule {
            source_labels = ["__journal_syslog_facility"]
            regex         = "^9$"
            target_label  = "facility_label"
            replacement   = "clock"
          }
          rule {
            source_labels = ["__journal_syslog_facility"]
            regex         = "^10$"
            target_label  = "facility_label"
            replacement   = "authpriv"
          }
          rule {
            source_labels = ["__journal_syslog_facility"]
            regex         = "^11$"
            target_label  = "facility_label"
            replacement   = "ftp"
          }
          rule {
            source_labels = ["__journal_syslog_facility"]
            regex         = "^15$"
            target_label  = "facility_label"
            replacement   = "cron"
          }
          rule {
            source_labels = ["__journal_syslog_facility"]
            regex         = "^16$"
            target_label  = "facility_label"
            replacement   = "local0"
          }
          rule {
            source_labels = ["__journal_syslog_facility"]
            regex         = "^17$"
            target_label  = "facility_label"
            replacement   = "local1"
          }
          rule {
            source_labels = ["__journal_syslog_facility"]
            regex         = "^18$"
            target_label  = "facility_label"
            replacement   = "local2"
          }
          rule {
            source_labels = ["__journal_syslog_facility"]
            regex         = "^19$"
            target_label  = "facility_label"
            replacement   = "local3"
          }
          rule {
            source_labels = ["__journal_syslog_facility"]
            regex         = "^20$"
            target_label  = "facility_label"
            replacement   = "local4"
          }
          rule {
            source_labels = ["__journal_syslog_facility"]
            regex         = "^21$"
            target_label  = "facility_label"
            replacement   = "local5"
          }
          rule {
            source_labels = ["__journal_syslog_facility"]
            regex         = "^22$"
            target_label  = "facility_label"
            replacement   = "local6"
          }
          rule {
            source_labels = ["__journal_syslog_facility"]
            regex         = "^23$"
            target_label  = "facility_label"
            replacement   = "local7"
          }
        }

        loki.source.journal "read" {
          forward_to    = [loki.write.endpoint.receiver]
          relabel_rules = loki.relabel.journal.rules
          max_age       = "12h"
          labels        = { job = "systemd-journal" }
        }

        loki.write "endpoint" {
          endpoint {
            url = "http://127.0.0.1:${toString cfg.port}/loki/api/v1/push"
          }
        }
      '';
    })
  ];
}
