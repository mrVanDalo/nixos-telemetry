# Goal:
# verify source forwards to a remote target while simultaneously running
# local loki + grafana + prometheus (source IS target-2), and assert both
# the remote target and the local backends receive the telemetry.
{ self, ... }:

{
  perSystem =
    { pkgs, ... }:
    {
      checks.forward-local = pkgs.testers.runNixOSTest {
        name = "forward-local";

        # source: collects logs + metrics, ships to remote target AND
        # runs local loki + grafana + prometheus (source == target-2).
        # The collector fans out: logs -> [otlp, otlphttp/loki],
        # metrics -> [prometheus, otlp].
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
                  exporter.endpoints.target = "target:4317";
                };
                alloy.enable = true;
                telegraf.enable = true;
                netdata.enable = false;
                prometheus.enable = true;
                loki.enable = true;
                grafana.enable = true;
              };
            };
          };

        # target: remote collector, receives via OTLP, debug + prometheus
        nodes.target =
          { ... }:
          {
            imports = [ self.nixosModules.telemetry ];
            networking.hostName = "target";
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
