Check out [OPTIONS.md](./OPTIONS.md)

A NixOS Flake that provides predefined telemetry configurations for various
observability tools, leveraging
[OpenTelemetry](https://opentelemetry.io/docs/collector/) as the core transport
layer. The aim is to simplify the deployment and configuration of telemetry
solutions like Prometheus, Netdata, and Grafana Alloy by shipping all telemetry
data through OpenTelemetry and sending it to analysis tools such as Loki or
Prometheus for further monitoring and visualization.

```mermaid
graph TD;
    subgraph Machine1
        Opentelemetry1["Opentelemetry"]
        Prometheus1["Prometheus"] --> Opentelemetry1
        Alloy1["Alloy"] --> Opentelemetry1
        Telegraf1["Telegraf"] --> Opentelemetry1
        netdata1["netdata"] --> Opentelemetry1
        subgraph nixos-container
            Alloy3["Alloy"]
        end
        Alloy3 --> Opentelemetry1
    end

    subgraph Machine2
        Opentelemetry2["Opentelemetry"]
        Prometheus2["Prometheus"] --> Opentelemetry2
        Alloy2["Alloy"] --> Opentelemetry2
        Telegraf2["Telegraf"] --> Opentelemetry2
        netdata2["netdata"] --> Opentelemetry2
    end

    Opentelemetry1 --> Opentelemetry2
```

## labels

Here are labels, which we try to always set.

_instance_name:_ Either the host name or the container name. Set on metrics (via
telegraf `global_tags`) and on logs (via alloy journal relabel).

_host_name:_ The host name, also for containers. Set on metrics (via the
OpenTelemetry collector `metricstransform` processor) and on logs (via alloy
journal relabel).
