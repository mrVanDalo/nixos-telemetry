# Goal:
# verify logs-only scenario with loki + grafana, and assert datasource provisioning
{ self, ... }:

{
  perSystem =
    { pkgs, ... }:
    {
      checks.loki-grafana = pkgs.testers.runNixOSTest {
        name = "loki-grafana";

        # machine: loki + grafana, no metrics backends
        nodes.machine = {
          imports = [ self.nixosModules.telemetry ];

          networking.hostName = "test-host";
          system.stateVersion = "25.05";

          telemetry = {
            enable = true;
            alloy.enable = true;
            loki.enable = true;
            grafana.enable = true;
          };
        };

        testScript = builtins.readFile ./test.py;
      };
    };
}
