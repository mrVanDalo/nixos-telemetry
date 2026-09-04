# Port guesses
# ------------
# Ports of *external* services that telemetry programs (telegraf inputs,
# prometheus exporters, ...) scrape. These do not configure any service;
# they only tell the scrapers where to look, so the user adjusts them to
# match their environment. Ports that configure a service (listener or
# receiver endpoints) live with the module that opens them.
{
  lib,
  ...
}:
with lib;
with types;
{
  options.telemetry.ports = {
    mongodb = mkOption {
      type = int;
      default = 27017;
      description = ''
        Port of the MongoDB server that telegraf scrapes metrics from.
      '';
    };
  };
}
