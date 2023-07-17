{
  description = "Nix shell for code-format tools";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/release-23.05";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    { self
    , nixpkgs
    , flake-utils
    }:

    flake-utils.lib.eachDefaultSystem (system:
    let
      pkgs = import nixpkgs { inherit system; };
    in
    {
      devShells.default = pkgs.mkShell {
        packages = with pkgs; [
          black # Code format Python
          chroma # Code syntax highlighter
          mdp # Terminal Markdown presenter
          nodePackages.prettier # Code format
          rustfmt # Code format Rust
          shellcheck # Code lint Shell
          shfmt # Code format Shell
        ];
      };
    });
}
