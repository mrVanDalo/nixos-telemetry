# Goal:
# verify the oneshot secrets service generates a random secret key file with
# correct permissions before grafana starts, and that grafana reads it via
# $__file{...} expansion.
{ self, ... }:

{
  perSystem =
    { pkgs, ... }:
    {
      checks.grafana-secrets = pkgs.testers.runNixOSTest {
        name = "grafana-secrets";

        nodes.machine = {
          imports = [ self.nixosModules.telemetry ];

          networking.hostName = "test-host";
          system.stateVersion = "25.05";

          telemetry = {
            enable = true;
            grafana.enable = true;
            # adminAccess defaults to "firstLoginChange" — tested on `machine`
          };
        };

        nodes.autogen = {
          imports = [ self.nixosModules.telemetry ];

          networking.hostName = "autogen-host";
          system.stateVersion = "25.05";

          telemetry = {
            enable = true;
            grafana = {
              enable = true;
              adminAccess = "autogenerate";
            };
          };
        };

        testScript = builtins.readFile ./test.py;
      };
    };
}
