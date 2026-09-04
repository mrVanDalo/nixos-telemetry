{
  config,
  pkgs,
  lib,
  ...
}:
with lib;
with types;
let
  cfg = config.telemetry.telegraf;

  # For TCP, dial a reachable address: wildcards resolve to loopback,
  # anything else is used as configured. IPv6 hosts are bracketed because
  # the plugin parses the address with net.SplitHostPort, which rejects
  # unbracketed IPv6; IPv4/hostname hosts stay verbatim so the metric
  # `server` tag value is unchanged.
  reachableHost =
    listen:
    let
      host =
        if listen == "0.0.0.0" || listen == "localhost" || listen == "" then
          "127.0.0.1"
        else if listen == "::" then
          "::1"
        else if listen == null then
          "127.0.0.1"
        else
          listen;
    in
    if hasInfix ":" host then "[${host}]" else host;

in
{
  options = {
    telemetry.telegraf = {
      enable = mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          enable telegraf to collect metrics.
        '';
      };
      inputs.procstat.pattern = mkOption {
        type = nullOr str;
        default = null;
        description = ''
          Regex pattern to select processes for procstat collection.
          This is not collected automatically because depending on the
          pattern the amount of metrics can become very big.
        '';
      };

      autowire =
        genAttrs
          [
            "zfs"
            "docker"
            "podman"
            "nginx"
            "memcached"
            "elasticsearch"
            "mysql"
            "mongodb"
            "rabbitmq"
            "smartd"
            "nvidia"
            "fail2ban"
            "chrony"
            "ntp"
            "wireless"
            "prometheus"
            "libvirt"
            "varnish"
          ]
          (app: {
            enable = mkOption {
              type = bool;
              default = config.telemetry.autowire.enable;
              description = ''
                Automatically scrape ${app} metrics with telegraf if ${app} is set up.
              '';
            };
          });
    };
    telemetry.ports.telegraf = mkOption {
      type = int;
      default = 8088;
      description = ''
        InfluxDB receiver port opened by the OpenTelemetry collector.
        Telegraf sends metrics to this port.
      '';
    };
  };

  config = lib.mkIf (config.telemetry.enable && cfg.enable) (
    lib.mkMerge [

      # wire telegraf with opentelemetry
      # -------------------------------
      (mkIf (config.telemetry.pipelines.metrics.hasSink) {

        # opentelemetry wireing
        services.opentelemetry-collector.settings = {
          receivers.influxdb.endpoint = "127.0.0.1:${toString config.telemetry.ports.telegraf}";
          service.pipelines.metrics.receivers = [ "influxdb" ];
        };

        services.telegraf.extraConfig.outputs.influxdb_v2.urls = [
          "http://127.0.0.1:${toString config.telemetry.ports.telegraf}"
        ];

      })

      # configure telegraf
      # -----------------
      {

        systemd.services.telegraf.path = [ pkgs.inetutils ];

        services.telegraf = {
          enable = mkDefault true;
          extraConfig = {
            global_tags = {
              instance_name = config.networking.hostName; # this will end up as `instance` label  in  prometheus
            };
            # https://github.com/influxdata/telegraf/tree/master/plugins/inputs < all them plugins
            inputs = {

              # todo : put this in under `metrics.exporters.*`
              cpu = { };
              diskio = { };
              disk = { };
              processes = { };
              system = { };
              systemd_units = { };
              temp = { };
              mem = { };

              # services
              # todo : add all kinds of services here
              #docker = (lib.mkIf config.components.virtualisation.docker.enable (lib.mkDefault {}));
            };
          };
        };
      }

      # process statistics metrics collection
      # --------------------------------------
      (mkIf (cfg.inputs.procstat.pattern != null) {
        services.telegraf.extraConfig.inputs.procstat.pattern = cfg.inputs.procstat.pattern;
      })

      # zfs metrics collection
      # -----------------------
      (mkIf (cfg.autowire.zfs.enable && config.boot.zfs.enabled) {
        services.telegraf.extraConfig.inputs.zfs = {
          poolMetrics = mkDefault true;
          datasetMetrics = mkDefault true;
        };
      })
      # docker metrics collection
      # --------------------------
      (mkIf (cfg.autowire.docker.enable && config.virtualisation.docker.enable) {
        services.telegraf.extraConfig.inputs.docker = { };
        users.users.telegraf.extraGroups = [ "docker" ];
      })

      # podman metrics collection
      # --------------------------
      (mkIf
        (
          cfg.autowire.podman.enable
          && config.virtualisation.podman.enable
          && config.virtualisation.podman.dockerSocket.enable
        )
        {
          services.telegraf.extraConfig.inputs.docker = {
            endpoint = "unix:///run/podman/podman.sock";
          };
          users.users.telegraf.extraGroups = [ "podman" ];
        }
      )

      # nginx metrics collection
      # -------------------------
      (mkIf
        (cfg.autowire.nginx.enable && config.services.nginx.enable && config.services.nginx.statusPage)
        {
          services.telegraf.extraConfig.inputs.nginx.urls = [
            "http://127.0.0.1:${toString config.services.nginx.defaultHTTPListenPort}/nginx_status"
          ];
        }
      )

      # postgresql metrics collection
      # ------------------------------
      #(mkIf (config.services.postgresql.enable) {
      #  services.postgresql.ensureUsers = [
      #    {
      #      name = "telegraf";
      #      ensureClauses = {
      #        membership = [ "pg_read_all_stats" ];
      #      };
      #    }
      #  ];
      #  services.telegraf.extraConfig.inputs.postgresql = {
      #    address = "host=/run/postgresql user=telegraf sslmode=disable";
      #    databases = [ "postgres" ];
      #  };
      #})

      # redis metrics collection
      # ------------------------
      #(
      #  let
      #    enabledServers = filterAttrs (
      #      _: server: server.enable && server.port != 0
      #    ) config.services.redis.servers;
      #  in
      #  mkIf (enabledServers != { }) {
      #    services.telegraf.extraConfig.inputs.redis.servers = map (
      #      server: "tcp://${reachableHost server.bind}:${toString server.port}"
      #    ) (attrValues enabledServers);
      #  }
      #)

      # memcached metrics collection
      # -----------------------------
      (mkIf (cfg.autowire.memcached.enable && config.services.memcached.enable) (mkMerge [
        (mkIf (config.services.memcached.enableUnixSocket) {
          # memcached creates the socket with the service umask; 0007 makes
          # it group-writable so the telegraf user can connect through it.
          users.users.telegraf.extraGroups = [ "memcached" ];
          systemd.services.memcached.serviceConfig.UMask = mkDefault "0007";
          services.telegraf.extraConfig.inputs.memcached.unix_sockets = [ "/run/memcached/memcached.sock" ];
        })
        (mkIf (!config.services.memcached.enableUnixSocket) {
          services.telegraf.extraConfig.inputs.memcached.servers = [
            "${reachableHost config.services.memcached.listen}:${toString config.services.memcached.port}"
          ];
        })
      ]))

      # elasticsearch metrics collection
      # ---------------------------------
      (mkIf (cfg.autowire.elasticsearch.enable && config.services.elasticsearch.enable) {
        services.telegraf.extraConfig.inputs.elasticsearch = {
          servers = [
            "http://${reachableHost config.services.elasticsearch.listenAddress}:${toString config.services.elasticsearch.port}"
          ];
        };
      })

      # mysql metrics collection
      # -------------------------
      (
        let
          socket = config.services.mysql.settings.mysqld.socket or "/run/mysqld/mysqld.sock";
        in
        mkIf (cfg.autowire.mysql.enable && config.services.mysql.enable) {
          services.mysql.ensureUsers = [
            {
              name = "telegraf";
              ensurePermissions = {
                "*.*" = "SELECT, PROCESS";
              };
            }
          ];
          services.telegraf.extraConfig.inputs.mysql.servers = [ "telegraf@unix(${socket})/" ];
        }
      )

      # mongodb metrics collection
      # ---------------------------
      (mkIf (cfg.autowire.mongodb.enable && config.services.mongodb.enable) {
        services.telegraf.extraConfig.inputs.mongodb.servers = [
          "mongodb://${reachableHost config.services.mongodb.bind_ip}:${toString config.telemetry.ports.mongodb}/?connect=direct"
        ];
      })

      # rabbitmq metrics collection
      # ----------------------------
      (mkIf (cfg.autowire.rabbitmq.enable && config.services.rabbitmq.managementPlugin.enable) {
        services.telegraf.extraConfig.inputs.rabbitmq = {
          # the management plugin binds to `listenAddress`, see upstream `management.tcp.ip`
          url = "http://${reachableHost config.services.rabbitmq.listenAddress}:${toString config.services.rabbitmq.managementPlugin.port}";
          # upstream NixOS has no credential options; guest/guest is rabbitmq's built-in user and telegraf's default for this input
          username = "guest";
          password = "guest";
        };
      })

      # zookeeper metrics collection
      # -----------------------------
      #(mkIf (config.services.zookeeper.enable) {
      #  services.zookeeper.extraConf = mkAfter "4lw.commands.whitelist=srvr,mntr";
      #  services.telegraf.extraConfig.inputs.zookeeper.servers = [
      #    "localhost:${toString config.services.zookeeper.port}"
      #  ];
      #})

      # smart disk health metrics collection
      # -------------------------------------
      (mkIf (cfg.autowire.smartd.enable && config.services.smartd.enable) {
        services.telegraf.extraConfig.inputs.smart = {
          use_sudo = mkDefault true;
          path_smartctl = mkDefault "${pkgs.smartmontools}/sbin/smartctl";
        };
        # sudo lives only in /run/wrappers/bin, which is not on the unit path by default
        systemd.services.telegraf.path = [ "/run/wrappers/bin" ];
        security.sudo.extraRules = [
          {
            users = [ "telegraf" ];
            commands = [
              {
                command = "${pkgs.smartmontools}/sbin/smartctl";
                options = [ "NOPASSWD" ];
              }
            ];
          }
        ];
      })

      # nvidia gpu metrics collection
      # ------------------------------
      (mkIf (cfg.autowire.nvidia.enable && config.hardware.nvidia.enabled) {
        services.telegraf.extraConfig.inputs.nvidia_smi = {
          bin_path = mkDefault "${config.hardware.nvidia.package.bin}/bin/nvidia-smi";
        };
      })

      # fail2ban jail metrics collection
      # ---------------------------------
      (mkIf (cfg.autowire.fail2ban.enable && config.services.fail2ban.enable) {
        services.telegraf.extraConfig.inputs.fail2ban = {
          use_sudo = mkDefault true;
        };
        systemd.services.telegraf.path = [
          "/run/wrappers/bin"
          pkgs.fail2ban
        ];
        security.sudo.extraRules = [
          {
            users = [ "telegraf" ];
            commands = [
              {
                command = "${pkgs.fail2ban}/bin/fail2ban-client status";
                options = [ "NOPASSWD" ];
              }
              {
                command = "${pkgs.fail2ban}/bin/fail2ban-client status *";
                options = [ "NOPASSWD" ];
              }
            ];
          }
        ];
      })

      # chrony time sync metrics collection
      # ------------------------------------
      (mkIf (cfg.autowire.chrony.enable && config.services.chrony.enable) {
        services.telegraf.extraConfig.inputs.chrony = { };
        users.users.telegraf.extraGroups = [ "chrony" ];
      })

      # ntp peer metrics collection
      # ----------------------------
      (mkIf (cfg.autowire.ntp.enable && config.services.ntp.enable) {
        services.telegraf.extraConfig.inputs.ntpq = { };
        systemd.services.telegraf.path = [ pkgs.ntp ];
      })

      # unbound resolver metrics collection
      # ------------------------------------
      #(mkIf (config.services.unbound.enable) {
      #  services.unbound.localControlSocketPath = mkDefault "/run/unbound/unbound.ctl";
      #  users.users.telegraf.extraGroups = [ config.services.unbound.group ];
      #  services.telegraf.extraConfig.inputs.unbound = {
      #    binary = "${pkgs.unbound}/bin/unbound-control";
      #    thread_as_tag = mkDefault true;
      #  };
      #})

      # wireless link metrics collection
      # ---------------------------------
      (mkIf (cfg.autowire.wireless.enable && config.networking.wireless.enable) {
        services.telegraf.extraConfig.inputs.wireless = { };
      })

      # prometheus server metrics collection
      # -------------------------------------
      (mkIf (cfg.autowire.prometheus.enable && config.services.prometheus.enable) {
        services.telegraf.extraConfig.inputs.prometheus = {
          urls = [
            "http://${reachableHost config.services.prometheus.listenAddress}:${toString config.services.prometheus.port}/metrics"
          ];
        };
      })

      # consul metrics collection
      # --------------------------
      #(
      #  let
      #    # nixpkgs' consul module exposes the HTTP API address only as
      #    # `alerts.consulAddr` ("host[:port]", default "localhost:8500").
      #    # Telegraf's consul input needs an explicit host:port; when the
      #    # port is omitted it defaults to consul's HTTP port 8500.
      #    addr = config.services.consul.alerts.consulAddr;
      #    parts = splitString ":" addr;
      #    hasPort = length parts > 1;
      #    # join with ":" survives a bracketed IPv6 host ("[::1]:8500")
      #    rawHost = if hasPort then concatStringsSep ":" (init parts) else addr;
      #    port = if hasPort then last parts else "8500";
      #    # reachableHost brackets bare IPv6 hosts; an already-bracketed one
      #    # is dialable as-is and must not be bracketed twice.
      #    host = if hasPrefix "[" rawHost then rawHost else reachableHost rawHost;
      #  in
      #  mkIf (config.services.consul.enable) {
      #    services.telegraf.extraConfig.inputs.consul = {
      #      address = "${host}:${port}";
      #    };
      #  }
      #)

      # libvirt metrics collection
      # ---------------------------
      (mkIf (cfg.autowire.libvirt.enable && config.virtualisation.libvirtd.enable) {
        services.telegraf.extraConfig.inputs.libvirt = {
          libvirt_uri = "qemu:///system";
        };
        users.users.telegraf.extraGroups = [ "libvirtd" ];
      })

      # varnish metrics collection
      # ---------------------------
      (mkIf (cfg.autowire.varnish.enable && config.services.varnish.enable) {
        services.telegraf.extraConfig.inputs.varnish = {
          binary = "${config.services.varnish.package}/bin/varnishstat";
          adm_binary = "${config.services.varnish.package}/bin/varnishadm";
        };
        users.users.telegraf.extraGroups = [ "varnish" ];
      })
    ]
  );
}
