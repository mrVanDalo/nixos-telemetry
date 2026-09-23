{
  config,
  lib,
  ...
}:
{
  options.telemetry.isSharedNetworkContainer = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = ''
      Set inside a container's evaluation to declare "I am a shared-network
      container whose agents push to the host collector over the shared
      loopback". The `telemetry-container-shared-network` module sets this to
      true by default. A container cannot derive its network mode from its
      own config (`privateNetwork` lives only in the host's
      `containers.<name>` submodule), so the imported module is the
      declaration point.
    '';
  };

  options.telemetry.isContainer = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = ''
      Set inside a container's evaluation to declare "I am a container".
      When true, all agents stamp container identity onto their telemetry:
      alloy adds the `container_name` / `is_container` labels to journal
      logs, telegraf adds them to `global_tags`, and netdata gets them as
      host labels plus receiver-side scrape labels on every metric
      (container_name defaults to the container's hostname). Metrics carry
      `host_name` stamped by telegraf from the system's own hostname — also
      inside a container. Only logs go without `host_name` here: alloy omits
      the journal hostname label and the container's collector skips hostname
      detection. A receiving host collector (isContainer = false) still fills
      an unset host.name with its own hostname.
    '';
  };

  options.telemetry.pipelines.container.hasSharedNetworkContainer = lib.mkOption {
    type = lib.types.bool;
    readOnly = true;
    internal = true;
    description = ''
      True if this is a NixOS system which contains at least one nixos-container
      with privateNetwork set to false.
      In this case we expect the nixos-container to send its traffic to the
      OpenTelemetry collector on the host system, instead of spawning one itself.
      This is mainly to prevent port clashes.
    '';
  };

  config = {
    # Host-side detection: any container sharing the host network namespace.
    # `config.containers` is empty inside a container evaluation (nspawn
    # containers have no children), so the flag is naturally false there.
    telemetry.pipelines.container.hasSharedNetworkContainer = lib.any (
      container: !container.privateNetwork
    ) (lib.attrValues config.containers);

    warnings =
      lib.optionals config.telemetry.enable (
        lib.optional
          (config.telemetry.pipelines.container.hasSharedNetworkContainer && !config.telemetry.pipelines.logs.hasExporters)
          ''
            telemetry: shared-network container detected but no logs sink is enabled
            (telemetry.loki.enable). The host collector's logs receiver stays
            closed and container alloy log pushes are refused — enable a logs
            sink or disable logging in the container's agents.
          ''
        ++ lib.optional
          (config.telemetry.pipelines.container.hasSharedNetworkContainer && !config.telemetry.pipelines.metrics.hasExporters)
          ''
            telemetry: shared-network container detected but no metrics sink is
            enabled (telemetry.prometheus.enable). The host collector's metrics
            receiver stays closed and container telegraf metric pushes are
            refused — enable a metrics sink or disable metrics in the
            container's agents.
          ''
      );
  };
}
