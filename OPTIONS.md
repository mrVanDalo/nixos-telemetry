## telemetry.apps.alloy.enable

Enable grafana-alloy to scrape journal logs.
This is the replacement for promtail which reached end of life.


*Type:*
` boolean `

*Default:*
` true `


*Declared by:*
 - [https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/apps/alloy.nix](https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/apps/alloy.nix)


## telemetry.apps.alloy.port

Port of the local Loki-compatible receiver.
This is the port alloy will send logs to.


*Type:*
` signed integer `

*Default:*
` 3500 `


*Declared by:*
 - [https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/apps/alloy.nix](https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/apps/alloy.nix)


## telemetry.apps.netdata.enable

enable netdata to collect metrics.


*Type:*
` boolean `

*Default:*
` true `


*Declared by:*
 - [https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/apps/netdata.nix](https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/apps/netdata.nix)


## telemetry.apps.netdata.port

Port netdata exposes its metrics on.


*Type:*
` signed integer `

*Default:*
` 19999 `


*Declared by:*
 - [https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/apps/netdata.nix](https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/apps/netdata.nix)


## telemetry.apps.opentelemetry.enable

enable opentelemetry collector

*Type:*
` boolean `

*Default:*
` true `


*Declared by:*
 - [https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/apps/opentelemetry.nix](https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/apps/opentelemetry.nix)


## telemetry.apps.opentelemetry.exporter.debug

enable debug exporter.

*Type:*
` null or one of "logs", "metrics" `

*Default:*
` null `


*Declared by:*
 - [https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/apps/opentelemetry.nix](https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/apps/opentelemetry.nix)


## telemetry.apps.opentelemetry.exporter.endpoint

endpoint to ship data to the next opentelementry collector

*Type:*
` null or string `

*Default:*
` null `

*Example:*
` "100.0.0.1:4317" `

*Declared by:*
 - [https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/apps/opentelemetry.nix](https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/apps/opentelemetry.nix)


## telemetry.apps.opentelemetry.receiver.endpoint

endpoint to receive the opentelementry collector data from other collectors

*Type:*
` null or string `

*Default:*
` null `

*Example:*
` "0.0.0.0:4317" `

*Declared by:*
 - [https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/apps/opentelemetry.nix](https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/apps/opentelemetry.nix)


## telemetry.apps.prometheus.enable

enable prometheus and configure it to scrape opentelemetry collector metrics
(in case `telemetry.apps.opentelemetry.enable = true`).


*Type:*
` boolean `

*Default:*
` false `


*Declared by:*
 - [https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/apps/prometheus.nix](https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/apps/prometheus.nix)


## telemetry.apps.prometheus.port

opentelemetry collector port to expose metrics for prometheus.


*Type:*
` signed integer `

*Default:*
` 8090 `


*Declared by:*
 - [https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/apps/prometheus.nix](https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/apps/prometheus.nix)


## telemetry.apps.prometheus.retentionTime

retention time of prometheus data. If you want to serialize a really long time, use thanos.


*Type:*
` string `

*Default:*
` "30d" `


*Declared by:*
 - [https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/apps/prometheus.nix](https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/apps/prometheus.nix)


## telemetry.apps.telegraf.enable

enable telegraf to collect metrics.


*Type:*
` boolean `

*Default:*
` true `


*Declared by:*
 - [https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/apps/telegraf.nix](https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/apps/telegraf.nix)


## telemetry.apps.telegraf.port

influxdb port opened by opentelemetry collector which telemetry will send metrics to.


*Type:*
` signed integer `

*Default:*
` 8088 `


*Declared by:*
 - [https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/apps/telegraf.nix](https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/apps/telegraf.nix)


## telemetry.enable

Whether to enable the NixOS telemetry system.
This is the main switch that controls all telemetry functionality.


*Type:*
` boolean `

*Default:*
` false `


*Declared by:*
 - [https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules](https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules)


## telemetry.logs.enable

Controls the collection of system logs.
When enabled, nixos-telemetry will collect logs from configured
services that are enabled in your NixOS configuration.


*Type:*
` boolean `

*Default:*
` true `


*Declared by:*
 - [https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules](https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules)


## telemetry.metrics.enable

Controls the collection of system metrics.
When enabled, nixos-telemetry will collect metrics from configured
services that are enabled in your NixOS configuration.


*Type:*
` boolean `

*Default:*
` true `


*Declared by:*
 - [https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules](https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules)


## telemetry.metrics.exporters.procstat.enable

Enable process statistics metrics collection via telegraf.


*Type:*
` boolean `

*Default:*
` true `


*Declared by:*
 - [https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/metrics/exporters/procstat.nix](https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/metrics/exporters/procstat.nix)


## telemetry.metrics.exporters.zfs.enable

Enable zfs metrics collection via telegraf.


*Type:*
` boolean `

*Default:*
` true `


*Declared by:*
 - [https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/metrics/exporters/zfs.nix](https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/metrics/exporters/zfs.nix)


