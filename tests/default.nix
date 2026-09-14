{
  imports = [
    ./container-telemetry-private-net
    ./container-telemetry-shared-net
    ./metrics
    ./log-pipeline
    ./loki-grafana
    ./forward-central
    ./forward-chain
    ./forward-fanout
    ./forward-local
    ./grafana-secrets
    ./collector-guard
  ];
}
