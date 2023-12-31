# Custom packages, that can be defined similarly to ones from nixpkgs
# Build them using 'nix build .#example' or (legacy) 'nix-build -A example'

{ pkgs ? (import ../nixpkgs.nix) { } }: {
  distrobox = pkgs.callPackage ./distrobox { };
  gitkraken = pkgs.callPackage ./gitkraken { };
  lima-bin = pkgs.callPackage ./lima-bin { };
  wavebox = pkgs.callPackage ./wavebox { };
}
