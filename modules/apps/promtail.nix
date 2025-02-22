{ config, lib, ... }:
with lib;
with types;
let
  cfg = config.telemetry.apps.promtail;
in
{
  options.telemetry.apps.promtail = {
    enable = mkOption {
      type = lib.types.bool;
      default = config.telemetry.logs.enable;
      description = ''
        enable prometail to scrape logs.
      '';
    };
    port = mkOption {
      type = int;
      default = 3500;
      description = ''
        port to provide promtail receiver port. This is the port promtail will send logs to
      '';
    };
  };

  config = mkMerge [

    # opentelemetry shippment
    # -----------------------
    (mkIf (config.telemetry.apps.promtail.enable && config.telemetry.apps.opentelemetry.enable) {
      services.opentelemetry-collector.settings = {

        service.pipelines.logs.receivers = [ "loki" ];

        receivers.loki = {
          protocols.http.endpoint = "127.0.0.1:${toString cfg.port}";
          use_incoming_timestamp = true;
        };

      };

      services.promtail.configuration.clients = [
        { url = "http://127.0.0.1:${toString cfg.port}/loki/api/v1/push"; }
      ];

    })

    # promtail configuration
    # ----------------------
    (mkIf (config.telemetry.apps.promtail.enable) {

      services.promtail = {
        enable = mkDefault true;
        configuration = {
          server.disable = true;
          positions.filename = "/var/cache/promtail/positions.yaml";

          scrape_configs =

            let
              _replace = index: replacement: ''{{ Replace .Value "${toString index}" "${replacement}" 1 }}'';
              _elseif = index: ''{{ else if eq .Value "${toString index}" }}'';
              _if = index: ''{{ if eq .Value "${toString index}" }}'';
              _end = ''{{ end }}'';
              elseblock = index: replacement: "${_elseif index}${_replace index replacement}";
              ifblock = index: replacement: "${_if index}${_replace index replacement}";
              createTemplateLine =
                list:
                "${
                  concatStrings (
                    imap0 (
                      index: replacement: if index == 0 then ifblock index replacement else elseblock index replacement
                    ) list
                  )
                }${_end}";
            in
            [
              {
                job_name = "journal";
                journal = {
                  json = true;
                  max_age = "12h";
                  labels.job = "systemd-journal";
                };
                pipeline_stages = [
                  {
                    # Set of key/value pairs of JMESPath expressions. The key will be
                    # the key in the extracted data while the expression will be the value,
                    # evaluated as a JMESPath from the source data.
                    json.expressions = {
                      # journalctl -o json | jq and you'll see these
                      boot_id = "_BOOT_ID";
                      facility = "SYSLOG_FACILITY";
                      facility_label = "SYSLOG_FACILITY";
                      instance = "_HOSTNAME";
                      msg = "MESSAGE";
                      priority = "PRIORITY";
                      priority_label = "PRIORITY";
                      transport = "_TRANSPORT";
                      unit = "_SYSTEMD_UNIT";
                      # coredump
                      #coredump_cgroup = "COREDUMP_CGROUP";
                      #coredump_exe = "COREDUMP_EXE";
                      #coredump_cmdline = "COREDUMP_CMDLINE";
                      #coredump_uid = "COREDUMP_UID";
                      #coredump_gid = "COREDUMP_GID";
                    };
                  }
                  {
                    # Set the unit (defaulting to the transport like audit and kernel)
                    template = {
                      source = "unit";
                      template = "{{if .unit}}{{.unit}}{{else}}{{.transport}}{{end}}";
                    };
                  }
                  {
                    # Normalize session IDs (session-1234.scope -> session.scope) to limit number of label values
                    replace = {
                      source = "unit";
                      expression = "^(session-\\d+.scope)$";
                      replace = "session.scope";
                    };
                  }
                  {
                    # Map priority to human readable
                    template = {
                      source = "priority_label";
                      #template = ''{{ if eq .Value "0" }}{{ Replace .Value "0" "emerg" 1 }}{{ else if eq .Value "1" }}{{ Replace .Value "1" "alert" 1 }}{{ else if eq .Value "2" }}{{ Replace .Value "2" "crit" 1 }}{{ else if eq .Value "3" }}{{ Replace .Value "3" "err" 1 }}{{ else if eq .Value "4" }}{{ Replace .Value "4" "warning" 1 }}{{ else if eq .Value "5" }}{{ Replace .Value "5" "notice" 1 }}{{ else if eq .Value "6" }}{{ Replace .Value "6" "info" 1 }}{{ else if eq .Value "7" }}{{ Replace .Value "7" "debug" 1 }}{{ end }}'';
                      template = createTemplateLine [
                        "emergency"
                        "alert"
                        "critical"
                        "error"
                        "warning"
                        "notice"
                        "info"
                        "debug"
                      ];
                    };
                  }
                  {
                    # Map facility to human readable
                    template = {
                      source = "facility_label";
                      template = createTemplateLine [
                        "kern" # Kernel messages
                        "user" # User-level messages
                        "mail" # Mail system	Archaic POSIX still supported and sometimes used (for more mail(1))
                        "daemon" # System daemons	All daemons, including systemd and its subsystems
                        "auth" # Security/authorization messages	Also watch for different facility 10
                        "syslog" # Messages generated internally by syslogd	For syslogd implementations (not used by systemd, see facility 3)
                        "lpr" # Line printer subsystem (archaic subsystem)
                        "news" # Network news subsystem (archaic subsystem)
                        "uucp" # UUCP subsystem (archaic subsystem)
                        "clock" # Clock daemon	systemd-timesyncd
                        "authpriv" # Security/authorization messages	Also watch for different facility 4
                        "ftp" # FTP daemon
                        "-" # NTP subsystem
                        "-" # Log audit
                        "-" # Log alert
                        "cron" # Scheduling daemon
                        "local0" # Local use 0 (local0)
                        "local1" # Local use 1 (local1)
                        "local2" # Local use 2 (local2)
                        "local3" # Local use 3 (local3)
                        "local4" # Local use 4 (local4)
                        "local5" # Local use 5 (local5)
                        "local6" # Local use 6 (local6)
                        "local7" # Local use 7 (local7)
                      ];
                    };
                  }
                  {
                    # Key is REQUIRED and the name for the label that will be created.
                    # Value is optional and will be the name from extracted data whose value
                    # will be used for the value of the label. If empty, the value will be
                    # inferred to be the same as the key.
                    labels = {
                      boot_id = "";
                      facility = "";
                      facility_label = "";
                      instance = "";
                      priority = "";
                      priority_label = "";
                      transport = "";
                      unit = "";
                    };
                  }
                  {
                    # Write the proper message instead of JSON
                    output.source = "msg";
                  }
                ];
              }
            ];
        };
      };
    })
  ];
}
