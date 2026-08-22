## telemetry.apps.alloy.enable

Enable grafana-alloy to scrape journal logs. This is the replacement for
promtail which reached end of life.

_Type:_ `boolean`

_Default:_ `true`

_Declared by:_

- [https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/apps/alloy.nix](https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/apps/alloy.nix)

## telemetry.apps.alloy.port

Port of the local Loki-compatible receiver. This is the port alloy will send
logs to.

_Type:_ `signed integer`

_Default:_ `3500`

_Declared by:_

- [https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/apps/alloy.nix](https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/apps/alloy.nix)

## telemetry.apps.grafana.enable

Enable Grafana and auto-provision datasources for any telemetry backends that
are enabled (Loki, Prometheus).

_Type:_ `boolean`

_Default:_ `false`

_Declared by:_

- [https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/apps/grafana.nix](https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/apps/grafana.nix)

## telemetry.apps.grafana.port

Port the Grafana HTTP server listens on.

_Type:_ `signed integer`

_Default:_ `3000`

_Declared by:_

- [https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/apps/grafana.nix](https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/apps/grafana.nix)

## telemetry.apps.grafana.secretKey

Secret key used by Grafana for encrypting secrets in the database. Override this
in production with a unique value.

_Type:_ `string`

_Default:_ `"SW2YcwTIb9zpOOhoPsMm"`

_Declared by:_

- [https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/apps/grafana.nix](https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/apps/grafana.nix)

## telemetry.apps.loki.enable

Enable Loki as a log storage backend. When combined with
`telemetry.apps.opentelemetry.enable`, logs collected by the OpenTelemetry
collector are pushed to Loki.

_Type:_ `boolean`

_Default:_ `false`

_Declared by:_

- [https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/apps/loki.nix](https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/apps/loki.nix)

## telemetry.apps.loki.port

Port the Loki HTTP server listens on.

_Type:_ `signed integer`

_Default:_ `3100`

_Declared by:_

- [https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/apps/loki.nix](https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/apps/loki.nix)

## telemetry.apps.netdata.enable

enable netdata to collect metrics.

_Type:_ `boolean`

_Default:_ `true`

_Declared by:_

- [https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/apps/netdata.nix](https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/apps/netdata.nix)

## telemetry.apps.netdata.port

Port netdata exposes its metrics on.

_Type:_ `signed integer`

_Default:_ `19999`

_Declared by:_

- [https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/apps/netdata.nix](https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/apps/netdata.nix)

## telemetry.apps.opentelemetry.enable

enable opentelemetry collector

_Type:_ `boolean`

_Default:_ `true`

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

## telemetry.apps.telegraf.enable

enable telegraf to collect metrics.

_Type:_ `boolean`

_Default:_ `true`

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

_Default:_ `true`

_Declared by:_

- [https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules](https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules)

## telemetry.metrics.enable

Controls the collection of system metrics. When enabled, nixos-telemetry will
collect metrics from configured services that are enabled in your NixOS
configuration.

_Type:_ `boolean`

_Default:_ `true`

_Declared by:_

- [https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules](https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules)

## telemetry.metrics.exporters.procstat.enable

Enable process statistics metrics collection via telegraf.

_Type:_ `boolean`

_Default:_ `true`

_Declared by:_

- [https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/metrics/exporters/procstat.nix](https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/metrics/exporters/procstat.nix)

## telemetry.metrics.exporters.zfs.enable

Enable zfs metrics collection via telegraf.

_Type:_ `boolean`

_Default:_ `true`

_Declared by:_

- [https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/metrics/exporters/zfs.nix](https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/metrics/exporters/zfs.nix)
