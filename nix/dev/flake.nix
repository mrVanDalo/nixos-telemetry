{
  description = "Dev-only inputs (interactive dev shells, ...).";

  inputs = {
    devshell.url = "github:numtide/devshell";
  };

  outputs = inputs: { inherit inputs; };
}
