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
        nixosModules.container-telemetry =
          { lib, ... }:
          {
            imports = [ self.nixosModules.telemetry ];
            config = {
              telemetry.enable = lib.mkDefault true; # import this module should be convenient
              telemetry.metrics.enable = lib.mkDefault false; # metrics of nixos-containers don't make much sense
              telemetry.logs.enable = lib.mkDefault true; # logs of nixos-containers are  interesting
              services.journald.extraConfig = "SystemMaxUse=1G"; # no need for storing a lot of logs.
            };
          };
        nixosModules.container-telemetry-non-private-network =
          { lib, ... }:
          {
            imports = [ self.nixosModules.container-telemetry ];
            config = {
              telemetry.apps.opentelemetry.enable = lib.mkDefault false; # we don't need a opentelemetry collector if one is running on the host AND we share the network
            };

          };

        nixosModules.default = self.nixosModules.telemetry;

      };
    };
}
