# contains app related configuration
{
  imports = [
    ./netdata.nix
    ./opentelemetry.nix
    ./prometheus.nix
    ./alloy.nix
    ./telegraf.nix
  ];
}
