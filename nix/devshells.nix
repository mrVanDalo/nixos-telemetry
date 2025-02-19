{ self, inputs, ... }:
{

  imports = [ inputs.devshell.flakeModule ];

  perSystem =
    {
      lib,
      pkgs,
      self',
      system,
      ...
    }:
    {
      devshells.default = {

        commands =
          let
            # generate our docs
            optionsDoc = pkgs.nixosOptionsDoc {
              options = self.nixosConfigurations.example.options.telemetry;
            };
          in
          [
            {
              help = "render markdown";
              name = "documentation-markdown";
              command = "cat ${optionsDoc.optionsCommonMark}";
            }
            {
              help = "render json";
              name = "documentation-json";
              command = "cat ${optionsDoc.optionsJSON}/share/doc/nixos/options.json";
            }
            {
              help = "render ascii";
              name = "documentation-ascii-doc";
              command = "cat ${optionsDoc.optionsAsciiDoc}";
            }
            {
              help = "render simple json";
              name = "documentation-json-simple";
              command = "cat ${optionsDoc.optionsJSON}/share/doc/nixos/options.json | jq 'with_entries(.value = .value.description)'";
            }
          ];

        packages = [
          pkgs.jq
        ];
      };
    };
}
