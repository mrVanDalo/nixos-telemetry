# Telemetry options documentation apps. Lives in the dev partition: only
# interactive users need these, so the doc tooling inputs stay out of
# consumers' lock files. Exposed via `partitionedAttrs.apps = "dev"`.
# `self` (the flake) is only a top-level flake-parts module argument, not a
# `perSystem` one.
{ self, ... }: {
  perSystem =
    {
      lib,
      pkgs,
      ...
    }:
    {
      apps =
        let

          repositoryUrl = "https://github.com/mrVanDalo/nixos-telemetry/tree/main";

          # The flake root, not this file's directory: declaration paths
          # below are rewritten relative to the repository root.
          flakeRoot = toString self;

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
              option:
              option
              // {
                declarations = map (
                  declaration: pkgs.lib.strings.replaceStrings [ flakeRoot ] [ repositoryUrl ] (toString declaration)
                ) option.declarations;
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

          # Standalone script so both `build-options` and `build-all` run
          # identical code without a nested `nix run` re-evaluating the flake.
          buildOptions = pkgs.writers.writeBashBin "build-options" ''
            # Write OPTIONS.md at the project root even when invoked from a subfolder.
            root="$(${pkgs.git}/bin/git rev-parse --show-toplevel 2>/dev/null || pwd)"
            ${pkgs.jq}/bin/jq -r 'to_entries | .[] | @json' < ${optionsJSONOutput} | \
            while read -r entry; do
                echo "$entry" | ${pkgs.mustache-go}/bin/mustache ${option-template}
                echo -e "\n"
            done > "$root/OPTIONS.md"
          '';

        in
        { }
        // (appCommand "build-options" "Generate OPTIONS.md from the telemetry options" ''
          ${buildOptions}/bin/build-options
        '')
        // (appCommand "options-json" "Print the full telemetry options JSON"
          "cat ${optionsDoc.optionsJSON}/share/doc/nixos/options.json"
        )
        // (appCommand "options-undocumented" "List telemetry options that have no description" ''
          cat ${optionsDoc.optionsJSON}/share/doc/nixos/options.json | \
            ${pkgs.jq}/bin/jq -r 'to_entries | map(select(.value.description == "This option has no description.")) | .[].key'
        '')
        // (appCommand "options-asciidoc" "Print the telemetry options as AsciiDoc"
          "cat ${optionsDoc.optionsAsciiDoc}"
        )
        // (appCommand "build-all" "Regenerate OPTIONS.md, then run nix fmt" ''
          root="$(${pkgs.git}/bin/git rev-parse --show-toplevel 2>/dev/null || pwd)"
          cd "$root" || exit 1
          ${buildOptions}/bin/build-options
          ${pkgs.nix}/bin/nix fmt
        '');
    };
}
