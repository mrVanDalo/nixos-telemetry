# Goal:
# verify OTLP fan-out: source ships to two independent targets simultaneously,
# and assert host identity is preserved on both.
{ self, ... }:

{
  perSystem =
    { pkgs, ... }:
    {
      checks.forward-fanout = pkgs.testers.runNixOSTest {
        name = "forward-fanout";

        # source: collects logs + metrics, fans out to target-1 AND target-2
        nodes.source =
          { ... }:
          {
            imports = [ self.nixosModules.telemetry ];
            networking.hostName = "source";
            networking.firewall.enable = false;
            system.stateVersion = "25.05";

            telemetry = {
              enable = true;
              logs.enable = true;
              metrics.enable = true;

              apps = {
                opentelemetry = {
                  enable = true;
                  exporter.endpoints = {
                    target1 = "target1:4317";
                    target2 = "target2:4317";
                  };
                };
                alloy.enable = true;
                telegraf.enable = true;
                netdata.enable = false;
                prometheus.enable = false;
                loki.enable = false;
              };
            };
          };

        # target-1: terminal, receives via OTLP, debug + prometheus to verify receipt
        nodes.target1 =
          { ... }:
          {
            imports = [ self.nixosModules.telemetry ];
            networking.hostName = "target1";
            networking.firewall.enable = false;
            system.stateVersion = "25.05";

            telemetry = {
              enable = true;
              logs.enable = true;
              metrics.enable = true;

              apps = {
                opentelemetry = {
                  enable = true;
                  receiver.endpoint = "0.0.0.0:4317";
                  exporter.debug = "logs";
                };
                prometheus.enable = true;
                alloy.enable = false;
                telegraf.enable = false;
                netdata.enable = false;
              };
            };
          };

        # target-2: terminal, receives via OTLP, debug + prometheus to verify receipt
        nodes.target2 =
          { ... }:
          {
            imports = [ self.nixosModules.telemetry ];
            networking.hostName = "target2";
            networking.firewall.enable = false;
            system.stateVersion = "25.05";

            telemetry = {
              enable = true;
              logs.enable = true;
              metrics.enable = true;

              apps = {
                opentelemetry = {
                  enable = true;
                  receiver.endpoint = "0.0.0.0:4317";
                  exporter.debug = "logs";
                };
                prometheus.enable = true;
                alloy.enable = false;
                telegraf.enable = false;
                netdata.enable = false;
              };
            };
          };

        testScript = builtins.readFile ./test.py;
      };
    };
}
