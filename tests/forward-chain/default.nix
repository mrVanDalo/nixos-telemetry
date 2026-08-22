# Goal:
# verify forwarding across source -> proxy -> sink, and assert host identity is preserved
{ self, ... }:

{
  perSystem =
    { pkgs, ... }:
    {
      checks.forward-chain = pkgs.testers.runNixOSTest {
        name = "forward-chain";

        # source: collects logs + metrics, ships to proxy
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
                  exporter.endpoint = "proxy:4317";
                };
                alloy.enable = true;
                telegraf.enable = true;
                netdata.enable = false;
                prometheus.enable = false;
              };
            };
          };

        # proxy: pure relay, receives from source, forwards to sink
        nodes.proxy =
          { ... }:
          {
            imports = [ self.nixosModules.telemetry ];
            networking.hostName = "proxy";
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
                  exporter.endpoint = "sink:4317";
                };
                alloy.enable = false;
                telegraf.enable = false;
                netdata.enable = false;
                prometheus.enable = false;
              };
            };
          };

        # sink: terminal, runs prometheus + debug exporter, no local source
        nodes.sink =
          { ... }:
          {
            imports = [ self.nixosModules.telemetry ];
            networking.hostName = "sink";
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
