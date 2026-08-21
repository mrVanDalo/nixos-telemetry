{ inputs, ... }:
{

  imports = [ inputs.devshell.flakeModule ];

  perSystem =
    { pkgs, ... }:
    {
      devshells.default = {

        commands = [
          {
            help = "Render OPTIONS.md via the flake markdown-hotfix app.";
            name = "render-docs";
            command = "nix run .#markdown-hotfix";
          }
        ];

        packages = [
          pkgs.jq
        ];
      };
    };
}
