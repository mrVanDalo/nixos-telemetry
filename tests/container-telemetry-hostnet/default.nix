# Goal:
# verify `nixosModules.container-telemetry` inside a NixOS declarative
# (systemd-nspawn) container that shares the host's network namespace
# (privateNetwork = false). Without a dedicated container netns the
# container's collector has no host bridge address to dial, so everything
# must be routed over loopback: the module's defaults (telemetry.enable +
# alloy.enable + journald cap) apply inside the container and the container
# ships its logs (alloy journal) and metrics (telegraf) over OTLP to
# localhost:4317 — the OpenTelemetry collector on the host system.
{ self, ... }:

{
  perSystem =
    { pkgs, ... }:
    {
      checks.container-telemetry-hostnet = pkgs.testers.runNixOSTest {
        name = "container-telemetry-hostnet";

        # host: OTLP receiver, prometheus (scrapes the collector's
        # prometheus exporter) and a debug exporter to assert log arrival.
        nodes.host = {
          imports = [ self.nixosModules.telemetry ];
          networking.hostName = "host";
          networking.firewall.enable = false;
          system.stateVersion = "25.05";

          telemetry = {
            enable = true;
            opentelemetry = {
              receiver.endpoint = "0.0.0.0:4317";
              exporter.debug = "logs";
            };
            prometheus.enable = true;
          };

          # the container under test: imports ONLY the container module
          # plus the exporter endpoint pointing at localhost — everything
          # else must come from the module's defaults. With
          # privateNetwork = false the container shares the host's network
          # namespace, so localhost:4317 lands on the host's collector.
          containers.telemetry = {
            autoStart = true;
            privateNetwork = false;
            config = {
              imports = [ self.nixosModules.container-telemetry ];
              system.stateVersion = "25.05";
              nix.enable = false;

              telemetry = {
                telegraf.enable = true; # metrics source inside the container
                opentelemetry.exporter.endpoints.host = "localhost:4317";
              };
            };
          };
        };

        testScript = builtins.readFile ./test.py;
      };
    };
}
