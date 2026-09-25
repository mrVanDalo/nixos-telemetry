# Goal:
# verify vector collection pipeline: journald logs -> OTLP -> debug exporter,
# and host metrics -> OTLP -> prometheus, with host_name/unit labels set.
{ self, ... }:

{
  perSystem =
    { pkgs, ... }:
    {
      checks.vector = pkgs.testers.runNixOSTest {
        name = "vector";

        # machine: vector (journald + host_metrics) -> opentelemetry
        #   - node "logs": vector -> opentelemetry -> debug exporter
        #   - node "metrics": vector -> opentelemetry -> prometheus
        # The debug exporter only handles one signal, so the two paths need
        # separate nodes.
        nodes = {
          logs = {
            imports = [ self.nixosModules.telemetry ];

            networking.hostName = "test-host";
            system.stateVersion = "25.05";

            telemetry = {
              enable = true;
              vector.enable = true;
              opentelemetry.exporter.debug = "logs";
            };
          };

          metrics = {
            imports = [ self.nixosModules.telemetry ];

            networking.hostName = "test-host";
            system.stateVersion = "25.05";

            telemetry = {
              enable = true;
              vector.enable = true;
              prometheus.enable = true;
            };

            # the full host_metrics collector set can emit gauges whose
            # values are NaN on a fresh VM (the OTLP encoder rejects NaN and
            # drops the whole batch); keep the collector set to the
            # integer-valued ones the test needs
            services.vector.settings.sources.host_metrics.collectors = [
              "cpu"
              "memory"
              "load"
              "host"
            ];
          };
        };

        testScript = builtins.readFile ./test.py;
      };
    };
}
