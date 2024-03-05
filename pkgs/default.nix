# Custom packages, that can be defined similarly to ones from nixpkgs
# Build them using 'nix build .#example' or (legacy) 'nix-build -A example'

{ pkgs ? (import ../nixpkgs.nix) { } }: {
  libfprint-2-tod1-vfs009a = pkgs.callPackage ./libfprint-2-tod1-vfs009a { };
  gitkraken = pkgs.callPackage ./gitkraken { };
  halloy = pkgs.callPackage ./halloy { };
  libdatachannel = pkgs.callPackage ./libdatachannel { };
  lima-bin = pkgs.callPackage ./lima-bin { };
  obs-studio = pkgs.callPackage ./obs-studio { };
  obs-studio-plugins = pkgs.callPackage ./obs-studio/plugins { };
}
