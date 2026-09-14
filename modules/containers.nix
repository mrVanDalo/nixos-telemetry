{
  config,
  lib,
  ...
}:
{
  options.telemetry = {
    autowire.containers.sharedNetwork = lib.mkOption {
      type = lib.types.bool;
      default = config.telemetry.autowire.enable;
      description = ''
        Host-side switch controlling whether shared-network containers
        (`privateNetwork = false`) are taken into account for telemetry
        auto-wiring. When enabled together with at least one shared-network
        container, the host opens its agent-facing collector receivers
        (loki, influxdb) so container agents push directly over the shared
        loopback. Defaults through the master switch
        `telemetry.autowire.enable`.
      '';
    };

    container.sharedNetwork = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Set inside a container's evaluation to declare "I am a shared-network
        container whose agents push to the host collector over the shared
        loopback". The `container-telemetry-shared-net` module sets this to
        true by default. A container cannot derive its network mode from its
        own config (`privateNetwork` lives only in the host's
        `containers.<name>` submodule), so the imported module is the
        declaration point.
      '';
    };

    pipelines.container.hasSharedNetworkContainer = lib.mkOption {
      type = lib.types.bool;
      readOnly = true;
      internal = true;
      description = ''
        Internal: the host has auto-wire enabled and at least one
        shared-network container, so agent-facing receivers must open.
      '';
    };
  };

  config = {
    # Host-side detection: any container sharing the host network namespace.
    # `config.containers` is empty inside a container evaluation (nspawn
    # containers have no children), so the flag is naturally false there —
    # host-side auto-wire is host-only.
    telemetry.pipelines.container.hasSharedNetworkContainer =
      config.telemetry.autowire.containers.sharedNetwork
      && lib.any (container: !container.privateNetwork) (lib.attrValues config.containers);

    warnings =
      lib.mkIf
        (
          config.telemetry.pipelines.container.hasSharedNetworkContainer
          && !config.telemetry.pipelines.logs.hasSink
          && !config.telemetry.pipelines.metrics.hasSink
        )
        [
          ''
            telemetry: shared-network container detected but no sink is enabled
            (telemetry.loki.enable / telemetry.prometheus.enable). The host's
            collector receivers stay closed and container agents' pushes are
            refused — enable at least one sink.
          ''
        ];
  };
}
