{ lib, ... }:
{
  imports = [
    (lib.mkRenamedOptionModule [ "telemetry" "alloy" "port" ] [ "telemetry" "ports" "alloy" ])
    (lib.mkRenamedOptionModule [ "telemetry" "telegraf" "port" ] [ "telemetry" "ports" "telegraf" ])
    (lib.mkRenamedOptionModule [ "telemetry" "prometheus" "port" ] [ "telemetry" "ports" "prometheus" ])
    (lib.mkRenamedOptionModule [ "telemetry" "loki" "port" ] [ "telemetry" "ports" "loki" ])
    (lib.mkRenamedOptionModule [ "telemetry" "netdata" "port" ] [ "telemetry" "ports" "netdata" ])
  ];
}
