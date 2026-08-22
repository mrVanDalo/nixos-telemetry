# Goal:
# verify log collection pipeline, and assert if labels are all set
{ self, ... }:

{
  perSystem =
    { pkgs, ... }:
    {
      checks.log-pipeline = pkgs.testers.runNixOSTest {
        name = "log-pipeline";

        # machine: alloy -> opentelemetry -> debug exporter
        nodes.machine = {
          imports = [ self.nixosModules.telemetry ];

          networking.hostName = "test-host";
          system.stateVersion = "25.05";

          telemetry = {
            enable = true;
            opentelemetry.exporter.debug = "logs";
            alloy.enable = true;
          };
        };

        testScript = builtins.readFile ./test.py;
      };
    };
}
