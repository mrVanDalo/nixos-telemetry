{
  description = "NixOS Telemetry Flake";

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    inputs@{ self, flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        inputs.flake-parts.flakeModules.partitions
      ];
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];

      # Outputs are only built when the named partition is loaded. Consumers
      # of this flake as a dependency will not see these inputs.
      partitionedAttrs.checks = "ci";
      partitionedAttrs.formatter = "ci";
      partitionedAttrs.devShells = "dev";

      # CI partition: lightweight inputs needed by CI runs. Loaded by
      # `nix flake check`.
      partitions.ci = {
        extraInputsFlake = ./nix/ci;
        module = {
          imports = [
            ./nix/ci/formatter.nix
            ./tests/default.nix
          ];
        };
      };

      # Dev partition: everything a human needs interactively. Loaded by
      # `nix develop`. Inherits CI inputs implicitly via partitionedAttrs.
      partitions.dev = {
        extraInputsFlake = ./nix/dev;
        module = {
          imports = [
            ./nix/dev/devshells.nix
          ];
        };
      };

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
        nixosModules.default = self.nixosModules.telemetry;
      };
    };
}
