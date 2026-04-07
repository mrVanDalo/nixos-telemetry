{ self }:
{
  name = "log-pipeline";

  nodes.machine =
    { lib, ... }:
    {
      imports = [ self.nixosModules.telemetry ];

      networking.hostName = "test-host";
      system.stateVersion = "25.05";

      telemetry = {
        enable = true;
        logs.enable = true;
        metrics.enable = false;

        apps.opentelemetry.enable = true;
        apps.alloy.enable = true;
      };

      # write logs to a file so we can verify them
      services.opentelemetry-collector.settings = {
        exporters."file/test" = {
          path = "/var/lib/opentelemetry-collector/logs.json";
        };
        service.pipelines.logs.exporters = [ "file/test" ];
      };

      # the file exporter requires the file to exist before starting
      systemd.services.opentelemetry-collector.preStart = lib.mkAfter ''
        touch /var/lib/opentelemetry-collector/logs.json
      '';
    };

  testScript = builtins.readFile ./log-pipeline.py;
}
