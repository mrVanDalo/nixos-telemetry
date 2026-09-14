{
  config,
  lib,
  ...
}:
with lib;
with types;
let
  cfg = config.telemetry."prometheus-exporters";

  mkScrapeConfig =
    {
      job_name,
      port,
      path ? "/metrics",
    }:
    {
      inherit job_name;
      metrics_path = path;
      scrape_interval = "10s";
      static_configs = [ { targets = [ "localhost:${toString port}" ]; } ];
    };

in
{
  options = {
    telemetry."prometheus-exporters" = {
      enable = mkOption {
        type = bool;
        default = false;
        description = ''
          Enable prometheus exporters to scrape service-level metrics.
          The node and systemd exporters are always enabled when this is active;
          other exporters are automatically wired when their corresponding
          NixOS service is detected on the machine.

          Can be overridden per app,
          e.g. `telemetry."prometheus-exporters".autowire.nginx.enable`.
        '';
      };

      autowire =
        genAttrs
          [
            "bind"
            "chrony"
            "dovecot"
            "elasticsearch"
            "fail2ban"
            "libvirt"
            "mongodb"
            "mysql"
            "nginx"
            "nvidia-gpu"
            "postfix"
            "postgres"
            "redis"
            "smartctl"
            "unbound"
            "varnish"
            "zfs"
          ]
          (app: {
            enable = mkOption {
              type = bool;
              default = config.telemetry.autowire.enable;
              description = ''
                Automatically enable the prometheus exporter with ${app}
                if the ${app} NixOS service is set up.
              '';
            };
          });
    };
  };

  config = mkIf (config.telemetry.enable && cfg.enable) (mkMerge [
    # ── always-on exporters ──────────────────────────────────────────
    {
      services.prometheus.exporters.node.enable = mkDefault true;
      services.prometheus.exporters.systemd.enable = mkDefault true;
      services.opentelemetry-collector.settings.receivers."prometheus/exporters".config.scrape_configs = [
        (mkScrapeConfig {
          job_name = "node";
          port = config.services.prometheus.exporters.node.port;
        })
        (mkScrapeConfig {
          job_name = "systemd";
          port = config.services.prometheus.exporters.systemd.port;
        })
      ];
    }

    # ── register the prometheus/exporters receiver in the pipeline ──
    # a pipeline only exists when a sink is configured; without one the
    # receiver definition above would be inert (see telegraf.nix, netdata.nix)
    (mkIf (config.telemetry.pipelines.metrics.hasSink && config.services.prometheus.exporters.node.enable) {
      services.opentelemetry-collector.settings.service.pipelines.metrics.receivers = [
        "prometheus/exporters"
      ];
    })

    # ── autowire: nginx ──────────────────────────────────────────────
    (mkIf (cfg.autowire.nginx.enable && config.services.nginx.enable) {
      services.prometheus.exporters.nginx.enable = mkDefault true;
      services.opentelemetry-collector.settings.receivers."prometheus/exporters".config.scrape_configs = [
        (mkScrapeConfig {
          job_name = "nginx";
          port = config.services.prometheus.exporters.nginx.port;
        })
      ];
    })

    # ── autowire: postgres ───────────────────────────────────────────
    (mkIf (cfg.autowire.postgres.enable && config.services.postgresql.enable) {
      services.prometheus.exporters.postgres.enable = mkDefault true;
      services.opentelemetry-collector.settings.receivers."prometheus/exporters".config.scrape_configs = [
        (mkScrapeConfig {
          job_name = "postgres";
          port = config.services.prometheus.exporters.postgres.port;
        })
      ];
    })

    # ── autowire: redis ──────────────────────────────────────────────
    (
      let
        enabledServers = filterAttrs (
          _: server: server.enable && server.port != 0
        ) config.services.redis.servers;
      in
      mkIf (cfg.autowire.redis.enable && enabledServers != { }) {
        services.prometheus.exporters.redis.enable = mkDefault true;
        services.opentelemetry-collector.settings.receivers."prometheus/exporters".config.scrape_configs = [
          (mkScrapeConfig {
            job_name = "redis";
            port = config.services.prometheus.exporters.redis.port;
          })
        ];
      }
    )

    # ── autowire: mongodb ────────────────────────────────────────────
    (mkIf (cfg.autowire.mongodb.enable && config.services.mongodb.enable) {
      services.prometheus.exporters.mongodb.enable = mkDefault true;
      services.opentelemetry-collector.settings.receivers."prometheus/exporters".config.scrape_configs = [
        (mkScrapeConfig {
          job_name = "mongodb";
          port = config.services.prometheus.exporters.mongodb.port;
        })
      ];
    })

    # ── autowire: elasticsearch ──────────────────────────────────────
    (mkIf (cfg.autowire.elasticsearch.enable && config.services.elasticsearch.enable) {
      services.prometheus.exporters.elasticsearch.enable = mkDefault true;
      services.opentelemetry-collector.settings.receivers."prometheus/exporters".config.scrape_configs = [
        (mkScrapeConfig {
          job_name = "elasticsearch";
          port = config.services.prometheus.exporters.elasticsearch.port;
        })
      ];
    })

    # ── autowire: mysql ──────────────────────────────────────────────
    (mkIf (cfg.autowire.mysql.enable && config.services.mysql.enable) {
      services.prometheus.exporters.mysqld.enable = mkDefault true;
      services.opentelemetry-collector.settings.receivers."prometheus/exporters".config.scrape_configs = [
        (mkScrapeConfig {
          job_name = "mysqld";
          port = config.services.prometheus.exporters.mysqld.port;
        })
      ];
    })

    # ── autowire: zfs ────────────────────────────────────────────────
    (mkIf (cfg.autowire.zfs.enable && config.boot.zfs.enabled) {
      services.prometheus.exporters.zfs.enable = mkDefault true;
      services.opentelemetry-collector.settings.receivers."prometheus/exporters".config.scrape_configs = [
        (mkScrapeConfig {
          job_name = "zfs";
          port = config.services.prometheus.exporters.zfs.port;
        })
      ];
    })

    # ── autowire: smartctl ───────────────────────────────────────────
    (mkIf (cfg.autowire.smartctl.enable && config.services.smartd.enable) {
      services.prometheus.exporters.smartctl.enable = mkDefault true;
      services.opentelemetry-collector.settings.receivers."prometheus/exporters".config.scrape_configs = [
        (mkScrapeConfig {
          job_name = "smartctl";
          port = config.services.prometheus.exporters.smartctl.port;
        })
      ];
    })

    # ── autowire: nvidia-gpu ─────────────────────────────────────────
    (mkIf (cfg.autowire.nvidia-gpu.enable && config.hardware.nvidia.enabled) {
      services.prometheus.exporters."nvidia-gpu".enable = mkDefault true;
      services.opentelemetry-collector.settings.receivers."prometheus/exporters".config.scrape_configs = [
        (mkScrapeConfig {
          job_name = "nvidia-gpu";
          port = config.services.prometheus.exporters."nvidia-gpu".port;
        })
      ];
    })

    # ── autowire: fail2ban ───────────────────────────────────────────
    (mkIf (cfg.autowire.fail2ban.enable && config.services.fail2ban.enable) {
      services.prometheus.exporters.fail2ban.enable = mkDefault true;
      services.opentelemetry-collector.settings.receivers."prometheus/exporters".config.scrape_configs = [
        (mkScrapeConfig {
          job_name = "fail2ban";
          port = config.services.prometheus.exporters.fail2ban.port;
        })
      ];
    })

    # ── autowire: chrony ─────────────────────────────────────────────
    (mkIf (cfg.autowire.chrony.enable && config.services.chrony.enable) {
      services.prometheus.exporters.chrony.enable = mkDefault true;
      services.opentelemetry-collector.settings.receivers."prometheus/exporters".config.scrape_configs = [
        (mkScrapeConfig {
          job_name = "chrony";
          port = config.services.prometheus.exporters.chrony.port;
        })
      ];
    })

    # ── autowire: libvirt ────────────────────────────────────────────
    (mkIf (cfg.autowire.libvirt.enable && config.virtualisation.libvirtd.enable) {
      services.prometheus.exporters.libvirt.enable = mkDefault true;
      services.opentelemetry-collector.settings.receivers."prometheus/exporters".config.scrape_configs = [
        (mkScrapeConfig {
          job_name = "libvirt";
          port = config.services.prometheus.exporters.libvirt.port;
        })
      ];
    })

    # ── autowire: varnish ────────────────────────────────────────────
    (mkIf (cfg.autowire.varnish.enable && config.services.varnish.enable) {
      services.prometheus.exporters.varnish.enable = mkDefault true;
      services.opentelemetry-collector.settings.receivers."prometheus/exporters".config.scrape_configs = [
        (mkScrapeConfig {
          job_name = "varnish";
          port = config.services.prometheus.exporters.varnish.port;
        })
      ];
    })

    # ── autowire: unbound ────────────────────────────────────────────
    (mkIf (cfg.autowire.unbound.enable && config.services.unbound.enable) {
      services.prometheus.exporters.unbound.enable = mkDefault true;
      services.opentelemetry-collector.settings.receivers."prometheus/exporters".config.scrape_configs = [
        (mkScrapeConfig {
          job_name = "unbound";
          port = config.services.prometheus.exporters.unbound.port;
        })
      ];
    })

    # ── autowire: bind ───────────────────────────────────────────────
    (mkIf (cfg.autowire.bind.enable && config.services.bind.enable) {
      services.prometheus.exporters.bind.enable = mkDefault true;
      services.opentelemetry-collector.settings.receivers."prometheus/exporters".config.scrape_configs = [
        (mkScrapeConfig {
          job_name = "bind";
          port = config.services.prometheus.exporters.bind.port;
        })
      ];
    })

    # ── autowire: dovecot ────────────────────────────────────────────
    (mkIf (cfg.autowire.dovecot.enable && config.services.dovecot2.enable) {
      services.prometheus.exporters.dovecot.enable = mkDefault true;
      services.opentelemetry-collector.settings.receivers."prometheus/exporters".config.scrape_configs = [
        (mkScrapeConfig {
          job_name = "dovecot";
          port = config.services.prometheus.exporters.dovecot.port;
        })
      ];
    })

    # ── autowire: postfix ────────────────────────────────────────────
    (mkIf (cfg.autowire.postfix.enable && config.services.postfix.enable) {
      services.prometheus.exporters.postfix.enable = mkDefault true;
      services.opentelemetry-collector.settings.receivers."prometheus/exporters".config.scrape_configs = [
        (mkScrapeConfig {
          job_name = "postfix";
          port = config.services.prometheus.exporters.postfix.port;
        })
      ];
    })

  ]);
}
