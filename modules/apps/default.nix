# contains app related configuration
{
  imports = [
    ./netdata.nix
    ./opentelemetry.nix
    ./prometheus.nix
    ./promtail.nix
    ./telegraf.nix
  ];
}
