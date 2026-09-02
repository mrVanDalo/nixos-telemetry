warning: Git tree '/home/palo/dev/nixos/nixos-telemetry' is dirty

## telemetry.alloy.enable

Convenience option that enables `services.alloy.enable` with opinionated
defaults and wires it into the OpenTelemetry collector.

Even without this flag, if `services.alloy.enable = true` is set directly, the
OTel wiring still happens automatically — the collector receives logs from any
enabled Alloy instance.

_Type:_ `boolean`

_Default:_ `false`

_Declared by:_

- [https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/alloy.nix](https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/alloy.nix)

## telemetry.enable

Whether to enable the NixOS telemetry system. This is the main switch that
orchestrates all telemetry functionality: it dynamically starts the
OpenTelemetry collector when a complete pipeline exists — a source and sink for
the same signal type are both active.

Services are auto-wired with the collector when enabled, whether you use the
convenience option `telemetry.&lt;app&gt;.enable` or set
`services.&lt;app&gt;.enable = true` directly. The collector configuration is
injected into each enabled service.

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

Convenience option that enables `services.grafana.enable` with opinionated
defaults and auto-provisions datasources for any telemetry backends that are
enabled (Loki, Prometheus).

Even without this flag, if `services.grafana.enable = true` is set directly, the
datasource provisioning still happens automatically.

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

Convenience option that enables `services.loki.enable` with opinionated defaults
and wires it as a log sink into the OpenTelemetry collector.

Even without this flag, if `services.loki.enable = true` is set directly, the
collector pushes logs to Loki automatically.

_Type:_ `boolean`

_Default:_ `false`

_Declared by:_

- [https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/loki.nix](https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/loki.nix)

## telemetry.netdata.enable

Convenience option that enables `services.netdata.enable` with opinionated
defaults and wires it as a metrics source into the OpenTelemetry collector.

Even without this flag, if `services.netdata.enable = true` is set directly, the
OTel wiring still happens automatically — the collector scrapes metrics from any
enabled Netdata instance.

_Type:_ `boolean`

_Default:_ `false`

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

## telemetry.ports.alloy

Loki receiver port opened by the OpenTelemetry collector. Alloy sends journal
logs to this port.

_Type:_ `signed integer`

_Default:_ `3500`

_Declared by:_

- [https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/alloy.nix](https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/alloy.nix)

## telemetry.ports.loki

Port the Loki HTTP server listens on. The OpenTelemetry collector sends logs to
this port.

_Type:_ `signed integer`

_Default:_ `3100`

_Declared by:_

- [https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/loki.nix](https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/loki.nix)

## telemetry.ports.netdata

Prometheus receiver port opened by the OpenTelemetry collector. Netdata exposes
metrics that the OpenTelemetry collector scrapes from this port.

_Type:_ `signed integer`

_Default:_ `19999`

_Declared by:_

- [https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/netdata.nix](https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/netdata.nix)

## telemetry.ports.prometheus

Port the OpenTelemetry collector exposes Prometheus metrics on. Prometheus
scrapes this port.

_Type:_ `signed integer`

_Default:_ `8090`

_Declared by:_

- [https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/prometheus.nix](https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/prometheus.nix)

## telemetry.ports.telegraf

InfluxDB receiver port opened by the OpenTelemetry collector. Telegraf sends
metrics to this port.

_Type:_ `signed integer`

_Default:_ `8088`

_Declared by:_

- [https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/telegraf.nix](https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/telegraf.nix)

## telemetry.prometheus.enable

Convenience option that enables `services.prometheus.enable` with opinionated
defaults and wires it as a metrics sink into the OpenTelemetry collector.

Even without this flag, if `services.prometheus.enable = true` is set directly,
the collector exposes its Prometheus endpoint and Prometheus scrapes it
automatically.

_Type:_ `boolean`

_Default:_ `false`

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

Convenience option that enables `services.telegraf.enable` with opinionated
defaults and wires it as a metrics source into the OpenTelemetry collector.

Even without this flag, if `services.telegraf.enable = true` is set directly,
the OTel wiring still happens automatically.

_Type:_ `boolean`

_Default:_ `false`

_Declared by:_

- [https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/telegraf.nix](https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/telegraf.nix)

## telemetry.telegraf.inputs.procstat.pattern

Process name pattern to collect metrics from (e.g. &#34;nginx&#34;,
&#34;java&#34;, &#34;.&#34; for all). Passed directly to telegraf&#39;s procstat
input `pattern` option. Set to a non-null value to enable process metrics
collection.

_Type:_ `null or string`

_Default:_ `null`

_Declared by:_

- [https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/telegraf.nix](https://github.com/mrVanDalo/nixos-telemetry/tree/main/modules/telegraf.nix)
