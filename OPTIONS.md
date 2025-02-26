## telemetry.apps.netdata.enable

enable netdata to collect metrics.

_Type:_ `boolean`

_Default:_ `false`

_Declared by:_

- [https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/apps/netdata.nix](https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/apps/netdata.nix)

## telemetry.apps.opentelemetry.enable

enable opentelemetry collector

_Type:_ `boolean`

_Default:_ `false`

_Declared by:_

- [https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/apps/opentelemetry.nix](https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/apps/opentelemetry.nix)

## telemetry.apps.opentelemetry.exporter.debug

enable debug exporter.

_Type:_ `null or one of "logs", "metrics"`

_Default:_ `null`

_Declared by:_

- [https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/apps/opentelemetry.nix](https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/apps/opentelemetry.nix)

## telemetry.apps.opentelemetry.exporter.endpoint

endpoint to ship data to the next opentelementry collector

_Type:_ `null or string`

_Default:_ `null`

_Example:_ `"100.0.0.1:4317"`

_Declared by:_

- [https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/apps/opentelemetry.nix](https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/apps/opentelemetry.nix)

## telemetry.apps.opentelemetry.metrics.endpoint

endpoint on where to provide opentelementry collector metrics

_Type:_ `string`

_Default:_ `"127.0.0.1:8100"`

_Declared by:_

- [https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/apps/opentelemetry.nix](https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/apps/opentelemetry.nix)

## telemetry.apps.opentelemetry.receiver.endpoint

endpoint to receive the opentelementry collector data from other collectors

_Type:_ `null or string`

_Default:_ `null`

_Example:_ `"0.0.0.0:4317"`

_Declared by:_

- [https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/apps/opentelemetry.nix](https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/apps/opentelemetry.nix)

## telemetry.apps.prometheus.enable

enable prometheus and configure it to scrape opentelemetry collector metrics (in
case `telemetry.apps.opentelemetry.enable = true`).

_Type:_ `boolean`

_Default:_ `false`

_Declared by:_

- [https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/apps/prometheus.nix](https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/apps/prometheus.nix)

## telemetry.apps.prometheus.port

opentelemetry collector port to expose metrics for prometheus.

_Type:_ `signed integer`

_Default:_ `8090`

_Declared by:_

- [https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/apps/prometheus.nix](https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/apps/prometheus.nix)

## telemetry.apps.prometheus.retentionTime

retention time of prometheus data. If you want to serialize a really long time,
use thanos.

_Type:_ `string`

_Default:_ `"30d"`

_Declared by:_

- [https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/apps/prometheus.nix](https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/apps/prometheus.nix)

## telemetry.apps.promtail.enable

enable prometail to scrape logs.

_Type:_ `boolean`

_Default:_ `false`

_Declared by:_

- [https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/apps/promtail.nix](https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/apps/promtail.nix)

## telemetry.apps.promtail.port

port to provide promtail receiver port. This is the port promtail will send logs
to

_Type:_ `signed integer`

_Default:_ `3500`

_Declared by:_

- [https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/apps/promtail.nix](https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/apps/promtail.nix)

## telemetry.apps.telegraf.enable

enable telegraf to collect metrics.

_Type:_ `boolean`

_Default:_ `false`

_Declared by:_

- [https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/apps/telegraf.nix](https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/apps/telegraf.nix)

## telemetry.apps.telegraf.port

influxdb port opened by opentelemetry collector which telemetry will send
metrics to.

_Type:_ `signed integer`

_Default:_ `8088`

_Declared by:_

- [https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/apps/telegraf.nix](https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/apps/telegraf.nix)

## telemetry.enable

Whether to enable the NixOS telemetry system. This is the main switch that
controls all telemetry functionality.

_Type:_ `boolean`

_Default:_ `false`

_Declared by:_

- [https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules](https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules)

## telemetry.logs.enable

Controls the collection of system logs. When enabled, nixos-telemetry will
collect logs from configured services that are enabled in your NixOS
configuration.

_Type:_ `boolean`

_Default:_ `false`

_Declared by:_

- [https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules](https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules)

## telemetry.metrics.enable

Controls the collection of system metrics. When enabled, nixos-telemetry will
collect metrics from configured services that are enabled in your NixOS
configuration.

_Type:_ `boolean`

_Default:_ `false`

_Declared by:_

- [https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules](https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules)

## telemetry.metrics.exporters.procstat.enable

This option has no description.

_Type:_ `boolean`

_Default:_ `false`

_Declared by:_

- [https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/metrics/exporters/procstat.nix](https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/metrics/exporters/procstat.nix)

## telemetry.metrics.exporters.zfs.enable

This option has no description.

_Type:_ `boolean`

_Default:_ `false`

_Declared by:_

- [https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/metrics/exporters/zfs.nix](https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/metrics/exporters/zfs.nix)
