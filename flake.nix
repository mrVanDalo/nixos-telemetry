{
  description = "NixOS Telemetry Flake";

  inputs = {
    devshell.url = "github:numtide/devshell";
    devshell.inputs.nixpkgs.follows = "nixpkgs";
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
    treefmt-nix.url = "github:numtide/treefmt-nix";
  };

  outputs =
    inputs@{ self, flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        ./nix/formatter.nix
        ./nix/devshells.nix
        ./tests/default.nix
      ];
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];

      perSystem =
        {
          lib,
          pkgs,
          self',
          system,
          ...
        }:
        {
          apps =
            let

              repoUrl = "https://github.com/mrVanDalo/nixos-telemetry/tree/main";

              telemetryOptions =
                (pkgs.lib.evalModules {
                  modules = [
                    self.nixosModules.telemetry
                    {
                      _module.check = false;
                    }
                  ];
                  specialArgs = {
                    inherit pkgs lib;
                  };
                }).options.telemetry;

              optionsDoc = pkgs.nixosOptionsDoc {
                options = telemetryOptions;
                warningsAreErrors = false;
                # replace declaration strings
                transformOptions =
                  opt:
                  opt
                  // {
                    declarations = map (
                      decl: pkgs.lib.strings.replaceStrings [ (toString ./.) ] [ repoUrl ] (toString decl)
                    ) opt.declarations;
                  };
              };

              optionsJSONOutput = "${optionsDoc.optionsJSON}/share/doc/nixos/options.json";
              option-template = pkgs.writeText "option-template" ''
                ## {{key}}

                {{value.description}}

                *Type:*
                ` {{{value.type}}} `

                *Default:*
                ` {{{value.default.text}}} `

                {{#value.example.text}}
                *Example:*
                ` {{{.}}} `
                {{/value.example.text}}

                *Declared by:*
                {{#value.declarations}}
                 - [{{.}}]({{.}})
                {{/value.declarations}}
              '';

              appCommand = name: description: command: {
                "${name}" = {
                  type = "app";
                  program = pkgs.writers.writeBashBin "${name}" command;
                  meta.description = description;
                };
              };

            in
            { }
            // (appCommand "markdown-hotfix" "Generate Markdown documentation from the telemetry options" ''
              ${pkgs.jq}/bin/jq -r 'to_entries | .[] | @json' < ${optionsJSONOutput} | \
              while read -r entry; do
                  echo "$entry" | ${pkgs.mustache-go}/bin/mustache ${option-template}
                  echo -e "\n"
              done
            '')
            // (appCommand "json-full" "Print the full telemetry options JSON"
              "cat ${optionsDoc.optionsJSON}/share/doc/nixos/options.json"
            )
            // (appCommand "asciidoc" "Print the telemetry options as AsciiDoc"
              "cat ${optionsDoc.optionsAsciiDoc}"
            )
            // (appCommand "json" "Print telemetry option names mapped to their descriptions"
              "cat ${optionsDoc.optionsJSON}/share/doc/nixos/options.json | ${pkgs.jq}/bin/jq 'with_entries(.value = .value.description)'"
            )
            // (appCommand "undocumented" "List telemetry options that have no description" ''
              cat ${optionsDoc.optionsJSON}/share/doc/nixos/options.json | \
                ${pkgs.jq}/bin/jq -r 'to_entries | map(select(.value.description == "This option has no description.")) | .[].key'
            '');
        };

      flake = {
        # The usual flake attributes can be defined here, including system-
        # agnostic ones like nixosModule and system-enumerating ones, although
        # those are more easily expressed in perSystem.
        nixosModules.telemetry = ./modules;
        nixosModules.telemetry-container-private-network =
          { lib, ... }:
          {
            imports = [ self.nixosModules.telemetry ];
            config = {
              telemetry.enable = lib.mkDefault true; # import this module should be convenient
              services.journald.settings.Journal.SystemMaxUse = "1G"; # no need for storing a lot of logs.
              # container identity: alloy stamps container_name/is_container
              # onto journal logs, telegraf onto metrics
              telemetry.isContainer = lib.mkDefault true;
            };
          };

        nixosModules.telemetry-container-shared-network =
          { lib, ... }:
          {
            imports = [ self.nixosModules.telemetry ];
            config = {
              # declares "I am a shared-network container": un-gates telegraf's
              # loopback output without a local sink; alloy's URL is hardcoded
              # to loopback already. Agents push to the host collector through
              # the shared loopback.
              telemetry.isSharedNetworkContainer = lib.mkDefault true;
              # container identity: alloy stamps container_name/is_container
              # onto journal logs, telegraf onto metrics
              telemetry.isContainer = lib.mkDefault true;
              # off in a shared-net container: netdata cannot push its metrics
              # to the host collector (its prometheus endpoint is pull-only,
              # a remote host cannot scrape into the container's netns), and
              # it would bind-clash on :19999 anyway. Telegraf covers metrics.
              # Re-enabling requires lib.mkOverride 49 — a deliberate act.
              services.netdata.enable = lib.mkForce false;
              # offset the container's alloy UI so it cannot clash with a host
              # alloy on :12345
              services.alloy.extraFlags = lib.mkDefault [
                "--server.http.listen-addr=127.0.0.1:12346"
              ];
              services.journald.settings.Journal.SystemMaxUse = lib.mkDefault "1G";
              # hard-off: in a shared-net container the host collector is the
              # destination, a local collector would bind-clash with it.
              # Re-enabling requires lib.mkOverride 49 — a deliberate act.
              services.opentelemetry-collector.enable = lib.mkForce false;
            };
          };

        nixosModules.default = self.nixosModules.telemetry;

      };
    };
}
