# Goal:
# exercise metrics pipeline end-to-end, and assert host_name label is set
{ self, ... }:

{
  perSystem =
    { pkgs, ... }:
    {
      checks.metrics = pkgs.testers.runNixOSTest {
        name = "metrics";

        # machine: telegraf + netdata -> opentelemetry -> prometheus, procstat exporter
        nodes.machine =
          { ... }:
          {
            imports = [ self.nixosModules.telemetry ];

            networking.hostName = "test-host";
            system.stateVersion = "25.05";

            telemetry = {
              enable = true;
              telegraf.enable = true;
              netdata.enable = true;
              prometheus.enable = true;
              telegraf.inputs.procstat.pattern = ".";
            };
          };

        testScript = builtins.readFile ./test.py;
      };
    };
}
