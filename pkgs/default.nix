# Custom packages, that can be defined similarly to ones from nixpkgs
# Build them using 'nix build .#example' or (legacy) 'nix-build -A example'

{ pkgs ? (import ../nixpkgs.nix) { } }: {
  distrobox = pkgs.callPackage ./distrobox { };
  gitkraken = pkgs.callPackage ./gitkraken { };
  libdatachannel = pkgs.callPackage ./libdatachannel { };
  lima-bin = pkgs.callPackage ./lima-bin { };
  obs-studio = pkgs.callPackage ./obs-studio { };
  obs-studio-plugins = pkgs.callPackage ./obs-studio/plugins { };
  quickemu = pkgs.callPackage ./quickemu { };
}
