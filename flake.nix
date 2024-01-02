{
  description = "kivikakk.ee";

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    ...
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs {inherit system;};
      inherit (pkgs) ruby jekyll;
    in {
      formatter = pkgs.alejandra;

      devShells.default = pkgs.mkShell {
        name = "kivikakk.ee";
        buildInputs = [
          ruby
          (jekyll.override {withOptionalDependencies = true;})
        ];
      };
    });
}
