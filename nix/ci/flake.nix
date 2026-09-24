{
  description = "CI-only inputs (formatters, ...).";

  inputs = {
    treefmt-nix.url = "github:numtide/treefmt-nix";
  };

  outputs = inputs: { inherit inputs; };
}
