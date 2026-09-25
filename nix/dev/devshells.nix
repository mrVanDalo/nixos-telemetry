{ inputs, ... }:
{

  imports = [ inputs.devshell.flakeModule ];

  perSystem =
    { pkgs, ... }:
    {
      devshells.default = {

        commands = [
          {
            help = "Print the full telemetry options JSON.";
            name = "options-json";
            command = "nix run .#options-json";
          }
          {
            help = "List telemetry options that have no description.";
            name = "options-undocumented";
            command = "nix run .#options-undocumented";
          }
          {
            help = "Print the telemetry options as AsciiDoc.";
            name = "options-asciidoc";
            command = "nix run .#options-asciidoc";
          }
          {
            help = "Regenerate OPTIONS.md, then run nix fmt.";
            name = "build-all";
            command = "nix run .#build-all";
          }
          {
            help = "Render OPTIONS.md via the flake build-options app.";
            name = "build-options";
            command = "nix run .#build-options";
          }
        ];

        packages = [
          pkgs.jq
        ];
      };
    };
}
