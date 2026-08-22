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
              opentelemetry.exporter.endpoints.proxy = "proxy:4317";
              alloy.enable = true;
              telegraf.enable = true;
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
              opentelemetry = {
                receiver.endpoint = "0.0.0.0:4317";
                exporter.endpoints.sink = "sink:4317";
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
              opentelemetry = {
                receiver.endpoint = "0.0.0.0:4317";
                exporter.debug = "logs";
              };
              prometheus.enable = true;
            };
          };

        testScript = builtins.readFile ./test.py;
      };
    };
}
