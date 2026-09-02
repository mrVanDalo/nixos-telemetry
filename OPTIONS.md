## telemetry.alloy.enable

Enable grafana-alloy to scrape journal logs. This is the replacement for
promtail which reached end of life.

_Type:_ `boolean`

_Default:_ `false`

_Declared by:_

- [https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/alloy.nix](https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/alloy.nix)

## telemetry.ports.alloy

Loki receiver port opened by the OpenTelemetry collector. Alloy sends journal
logs to this port.

_Type:_ `signed integer`

_Default:_ `3500`

_Declared by:_

- [https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/alloy.nix](https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/alloy.nix)

## telemetry.enable

Whether to enable the NixOS telemetry system. This is the main switch that
orchestrates all telemetry functionality: it starts the OpenTelemetry collector
when a complete pipeline exists, and apps are individually opt-in
(`telemetry.&lt;app&gt;.enable`).

_Type:_ `boolean`

_Default:_ `false`

_Declared by:_

- [https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules](https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules)

## telemetry.grafana.adminAccess

How the initial admin account access is configured:

- `anonymous`: anonymous access is enabled with the Viewer role, so dashboards
  can be viewed without logging in.
- `autogenerate`: a random admin password is generated on first start and stored
  in a file referenced via `$__file{}`. No anonymous access.
- `firstLoginChange`: the default admin credentials are used and Grafana forces
  a password change on first login. No anonymous access.

_Type:_ `one of "anonymous", "autogenerate", "firstLoginChange"`

_Default:_ `"firstLoginChange"`

_Declared by:_

- [https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/grafana.nix](https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/grafana.nix)

## telemetry.grafana.autogenerateSecretKey

Automatically generate a persistent Grafana secret key on first start and point
`security.secret_key` at it via `$__file{}`. Disable to manage the secret key
yourself.

_Type:_ `boolean`

_Default:_ `true`

_Declared by:_

- [https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/grafana.nix](https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/grafana.nix)

## telemetry.grafana.enable

Enable Grafana and auto-provision datasources for any telemetry backends that
are enabled (Loki, Prometheus).

_Type:_ `boolean`

_Default:_ `false`

_Declared by:_

- [https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/grafana.nix](https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/grafana.nix)

## telemetry.grafana.http_addr

Address the Grafana HTTP server listens on.

_Type:_ `string`

_Default:_ `"127.0.0.1"`

_Declared by:_

- [https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/grafana.nix](https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/grafana.nix)

## telemetry.grafana.http_port

Port the Grafana HTTP server listens on.

_Type:_ `signed integer`

_Default:_ `3000`

_Declared by:_

- [https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/grafana.nix](https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/grafana.nix)

## telemetry.loki.enable

Enable Loki as a log storage backend. When combined with `telemetry.enable`,
logs collected by the OpenTelemetry collector are pushed to Loki.

_Type:_ `boolean`

_Default:_ `false`

_Declared by:_

- [https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/loki.nix](https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/loki.nix)

## telemetry.ports.loki

Port the Loki HTTP server listens on. The OpenTelemetry collector sends logs to
this port.

_Type:_ `signed integer`

_Default:_ `3100`

_Declared by:_

- [https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/loki.nix](https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/loki.nix)

## telemetry.netdata.enable

enable netdata to collect metrics.

_Type:_ `boolean`

_Default:_ `false`

_Declared by:_

- [https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/netdata.nix](https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/netdata.nix)

## telemetry.ports.netdata

Port netdata exposes its metrics on. The OpenTelemetry collector scrapes
metrics from this port.

_Type:_ `signed integer`

_Default:_ `19999`

_Declared by:_

- [https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/netdata.nix](https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/netdata.nix)

## telemetry.opentelemetry.exporter.debug

enable debug exporter.

_Type:_ `null or one of "logs", "metrics"`

_Default:_ `null`

_Declared by:_

- [https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/opentelemetry.nix](https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/opentelemetry.nix)

## telemetry.opentelemetry.exporter.endpoints

Named OTLP/gRPC endpoints to ship telemetry to. Each attribute becomes a
separate `otlp/&lt;name&gt;` exporter so the collector can fan out to one or
more downstream collectors simultaneously.

_Type:_ `attribute set of string`

_Default:_ `{ }`

_Example:_ `{
  backup = "100.0.0.2:4317";
  primary = "100.0.0.1:4317";
}`

_Declared by:_

- [https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/opentelemetry.nix](https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/opentelemetry.nix)

## telemetry.opentelemetry.receiver.endpoint

endpoint to receive the opentelementry collector data from other collectors

_Type:_ `null or string`

_Default:_ `null`

_Example:_ `"0.0.0.0:4317"`

_Declared by:_

- [https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/opentelemetry.nix](https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/opentelemetry.nix)

## telemetry.prometheus.enable

enable prometheus and configure it to scrape opentelemetry collector metrics (in
case `telemetry.enable = true`).

_Type:_ `boolean`

_Default:_ `false`

_Declared by:_

- [https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/prometheus.nix](https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/prometheus.nix)

## telemetry.ports.prometheus

Port the OpenTelemetry collector exposes Prometheus metrics on. Prometheus
scrapes this port.

_Type:_ `signed integer`

_Default:_ `8090`

_Declared by:_

- [https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/prometheus.nix](https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/prometheus.nix)

## telemetry.prometheus.retentionTime

retention time of prometheus data. If you want to serialize a really long time,
use thanos.

_Type:_ `string`

_Default:_ `"30d"`

_Declared by:_

- [https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/prometheus.nix](https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/prometheus.nix)

## telemetry.telegraf.enable

enable telegraf to collect metrics.

_Type:_ `boolean`

_Default:_ `false`

_Declared by:_

- [https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/telegraf.nix](https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/telegraf.nix)

## telemetry.telegraf.inputs.procstat.enable

Enable process statistics metrics collection via telegraf.

_Type:_ `boolean`

_Default:_ `false`

_Declared by:_

- [https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/telegraf.nix](https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/telegraf.nix)

## telemetry.telegraf.inputs.zfs.enable

Enable zfs metrics collection via telegraf.

_Type:_ `boolean`

_Default:_ `false`

_Declared by:_

- [https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/telegraf.nix](https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/telegraf.nix)

## telemetry.ports.telegraf

InfluxDB receiver port opened by the OpenTelemetry collector. Telegraf sends
metrics to this port.

_Type:_ `signed integer`

_Default:_ `8088`

_Declared by:_

- [https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/telegraf.nix](https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/telegraf.nix)
