# Goal:
# exercise metrics pipeline end-to-end, and assert host_name label is set
{ self, ... }:

{
  perSystem =
    { pkgs, ... }:
    {
      checks.metrics = pkgs.testers.runNixOSTest {
        name = "metrics";

        # machine: telegraf + netdata -> opentelemetry -> prometheus, procstat + zfs exporters
        nodes.machine =
          { ... }:
          {
            imports = [ self.nixosModules.telemetry ];

            networking.hostName = "test-host";
            system.stateVersion = "25.05";

            telemetry = {
              enable = true;
              logs.enable = false;
              metrics.enable = true;

              metrics.exporters.procstat.enable = true;
              metrics.exporters.zfs.enable = true;

              apps = {
                opentelemetry.enable = true;
                telegraf.enable = true;
                netdata.enable = true;
                prometheus.enable = true;
              };
            };
          };

        testScript = builtins.readFile ./test.py;
      };
    };
}
