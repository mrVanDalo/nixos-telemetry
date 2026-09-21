# Goal:
# verify `nixosModules.telemetry-container-shared-network` inside a NixOS
# declarative (systemd-nspawn) container that shares the host's network
# namespace (privateNetwork = false). The container's agents (alloy,
# telegraf) push directly to the host collector over the shared loopback —
# auto-wire opens the host's loki (:3500) and influxdb (:8088) receivers
# because a shared-network container exists. The container's alloy UI port
# is moved off :12345 (as the shared-network warning recommends) because a
# host alloy occupies the default port.
{ self, ... }:

{
  perSystem =
    { pkgs, ... }:
    {
      checks.container-telemetry-shared-net = pkgs.testers.runNixOSTest {
        name = "container-telemetry-shared-net";

        # host: sinks + its own alloy on the DEFAULT UI port :12345 —
        # exactly the clash scenario the container must avoid.
        nodes.host = {
          imports = [ self.nixosModules.telemetry ];
          networking.hostName = "host";
          networking.firewall.enable = false;
          system.stateVersion = "25.05";

          telemetry = {
            enable = true;
            alloy.enable = true; # host alloy, UI on :12345
            prometheus.enable = true;
            loki.enable = true;
            # debug exporter writes each received log record to the
            # collector's journal — the test greps it for the marker
            opentelemetry.exporter.debug = "logs";
          };

          # the container under test: imports ONLY the shared-net module —
          # everything else must come from the module's defaults plus the
          # explicit agent enables. With privateNetwork = false the
          # container shares the host's network namespace, so its agents'
          # loopback pushes land on the host's collector. The alloy UI
          # port is offset to :12346 as recommended by the shared-network
          # warning (the host alloy owns :12345).
          containers.telemetry = {
            autoStart = true;
            privateNetwork = false;
            config = {
              imports = [ self.nixosModules.telemetry-container-shared-network ];
              system.stateVersion = "25.05";
              nix.enable = false;

              telemetry = {
                enable = true;
                alloy.enable = true; # logs source inside the container
                telegraf.enable = true; # metrics source inside the container
              };
              services.alloy.extraFlags = [ "--server.http.listen-addr=127.0.0.1:12346" ];
            };
          };
        };

        testScript = builtins.readFile ./test.py;
      };
    };
}
