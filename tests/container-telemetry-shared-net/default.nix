# Goal:
# verify `nixosModules.container-telemetry-shared-net` inside a NixOS
# declarative (systemd-nspawn) container that shares the host's network
# namespace (privateNetwork = false). The container's agents (alloy,
# telegraf) push directly to the host collector over the shared loopback —
# auto-wire opens the host's loki (:3500) and influxdb (:8088) receivers
# because a shared-network container exists. No collector runs inside the
# container (`mkForce false`), eliminating the bind-race footgun.
{ self, ... }:

{
  perSystem =
    { pkgs, ... }:
    {
      checks.container-telemetry-hostnet = pkgs.testers.runNixOSTest {
        name = "container-telemetry-hostnet";

        # host: sinks only — no receiver.endpoint, no agents. Auto-wire
        # opens the agent-facing receivers from the container topology.
        nodes.host = {
          imports = [ self.nixosModules.telemetry ];
          networking.hostName = "host";
          networking.firewall.enable = false;
          system.stateVersion = "25.05";

          telemetry = {
            enable = true;
            prometheus.enable = true;
            loki.enable = true;
          };

          # the container under test: imports ONLY the shared-net module —
          # everything else must come from the module's defaults plus the
          # explicit agent enables. With privateNetwork = false the
          # container shares the host's network namespace, so its agents'
          # loopback pushes land on the host's collector.
          containers.telemetry = {
            autoStart = true;
            privateNetwork = false;
            config = {
              imports = [ self.nixosModules.container-telemetry-shared-net ];
              system.stateVersion = "25.05";
              nix.enable = false;

              telemetry = {
                enable = true;
                alloy.enable = true; # logs source inside the container
                telegraf.enable = true; # metrics source inside the container
              };
            };
          };
        };

        testScript = builtins.readFile ./test.py;
      };
    };
}
