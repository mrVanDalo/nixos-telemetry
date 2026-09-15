# Goal:
# verify `nixosModules.telemetry-container-private-network` inside a NixOS declarative
# (systemd-nspawn) container: the module's wiring defaults (telemetry.enable +
# journald cap) apply inside the container and the container ships its logs
# (alloy journal) and metrics (telegraf) over OTLP to the OpenTelemetry
# collector on the host system. The agents (alloy, telegraf) are enabled
# explicitly in the test — the module wires, it does not enable apps.
{ self, ... }:

{
  perSystem =
    { pkgs, ... }:
    {
      checks.container-telemetry-private-net = pkgs.testers.runNixOSTest {
        name = "container-telemetry-private-net";

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
          # plus the exporter endpoint pointing at the host — everything
          # else must come from the module's defaults.
          containers.telemetry = {
            autoStart = true;
            privateNetwork = true;
            hostAddress = "192.168.100.10";
            localAddress = "192.168.100.11";
            config = {
              imports = [ self.nixosModules.telemetry-container-private-network ];
              system.stateVersion = "25.05";
              nix.enable = false;

              telemetry = {
                alloy.enable = true; # logs source inside the container
                telegraf.enable = true; # metrics source inside the container
                opentelemetry.exporter.endpoints.host = "192.168.100.10:4317";
              };
            };
          };
        };

        testScript = builtins.readFile ./test.py;
      };
    };
}
