{
  description = "Nix shell for file sync tools";

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
          croc # Terminal file transfer
          mktorrent # Terminal torrent creator
          rclone # Terminal cloud storage client
          s3cmd # Terminal cloud storage client
          zsync # Terminal file sync
        ];
      };
    });
}
