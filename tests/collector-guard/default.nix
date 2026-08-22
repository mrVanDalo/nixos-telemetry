# Goal: verify the collector is NOT enabled when telemetry.enable is set but no
# complete pipeline (no receiver+exporter pair) exists — a pipeline-less
# collector cannot start. Also verify a complete pipeline DOES enable it.
{ self, ... }:
{
  perSystem = { pkgs, ... }: {
    checks.collector-guard = pkgs.testers.runNixOSTest {
      name = "collector-guard";
      # machine: telemetry on, no source and no sink ⇒ no pipeline ⇒ collector disabled.
      nodes.machine = {
        imports = [ self.nixosModules.telemetry ];
        networking.hostName = "machine";
        system.stateVersion = "25.05";
        telemetry.enable = true;
      };
      # pipeline: alloy source + debug sink ⇒ complete logs pipeline ⇒ collector enabled.
      nodes.pipeline = {
        imports = [ self.nixosModules.telemetry ];
        networking.hostName = "pipeline";
        system.stateVersion = "25.05";
        telemetry = {
          enable = true;
          alloy.enable = true;
          opentelemetry.exporter.debug = "logs";
        };
      };
      testScript = builtins.readFile ./test.py;
    };
  };
}
