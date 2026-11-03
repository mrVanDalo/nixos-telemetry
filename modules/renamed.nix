{ lib, ... }:
{
  imports = [
    (lib.mkRenamedOptionModule [ "telemetry" "alloy" "port" ] [ "telemetry" "ports" "alloy" ])
    (lib.mkRenamedOptionModule [ "telemetry" "telegraf" "port" ] [ "telemetry" "ports" "telegraf" ])
    (lib.mkRenamedOptionModule [ "telemetry" "prometheus" "port" ] [ "telemetry" "ports" "prometheus" ])
    (lib.mkRenamedOptionModule [ "telemetry" "loki" "port" ] [ "telemetry" "ports" "loki" ])
    (lib.mkRenamedOptionModule [ "telemetry" "netdata" "port" ] [ "telemetry" "ports" "netdata" ])
    # Varnish Cache renamed itself to Vinyl Cache; nixpkgs removed both the
    # `services.varnish` module and the `prometheus-varnish-exporter` package.
    (lib.mkRemovedOptionModule [ "telemetry" "telegraf" "autowire" "varnish" ]
      "nixpkgs dropped the `services.varnish` module (see `services.vinyl-cache`), so there is no varnish instance left to scrape."
    )
    (lib.mkRemovedOptionModule [
      "telemetry"
      "prometheus-exporters"
      "autowire"
      "varnish"
    ] "nixpkgs dropped the `prometheus-varnish-exporter` package and the `services.varnish` module.")
  ];
}
