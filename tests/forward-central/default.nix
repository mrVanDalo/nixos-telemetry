# Goal:
# verify OTLP forwarding source -> sink, and assert host identity is preserved
{ self, ... }:

{
  perSystem =
    { pkgs, ... }:
    {
      checks.forward-central = pkgs.testers.runNixOSTest {
        name = "forward-central";

        # source: collects logs + metrics, ships to sink via OTLP
        nodes.source =
          { ... }:
          {
            imports = [ self.nixosModules.telemetry ];
            networking.hostName = "source";
            # multi-machine OTLP needs the receiver port reachable across nodes;
            # the NixOS firewall blocks it by default, so disable it for this test
            networking.firewall.enable = false;
            system.stateVersion = "25.05";

            telemetry = {
              enable = true;
              logs.enable = true;
              metrics.enable = true;

              apps = {
                # ship everything to the central sink
                opentelemetry = {
                  enable = true;
                  exporter.endpoint = "sink:4317";
                };
                alloy.enable = true; # log source
                telegraf.enable = true; # metric source
                netdata.enable = false; # one metric source is enough
                prometheus.enable = false; # no local sink
              };
            };
          };

        # sink: central server, runs prometheus + debug exporter, no local source
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
                  # `exporter.debug = "logs"` makes logs.hasSink true so the OTLP
                  # receiver is wired into the logs pipeline.
                  exporter.debug = "logs";
                };
                # prometheus is the metrics sink: it makes metrics.hasSink true so
                # the OTLP receiver is wired into the metrics pipeline, then scrapes
                # the collector's prometheus exporter.
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
