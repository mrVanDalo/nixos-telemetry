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
      partitionedAttrs.apps = "dev";
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
      # `nix develop`. Its inputs stay out of consumers' lock files; the
      # apps and devShells outputs are exposed via partitionedAttrs.
      partitions.dev = {
        extraInputsFlake = ./nix/dev;
        module = {
          imports = [
            ./nix/dev/devshells.nix
            ./nix/dev/apps.nix
          ];
        };
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
