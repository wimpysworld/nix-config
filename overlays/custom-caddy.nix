# https://github.com/jnsgruk/nixos-config/blob/main/overlays/custom-caddy.nix
# https://mdleom.com/blog/2021/12/27/caddy-plugins-nixos/#build-custom-plugins-with-xcaddy
# https://vincent.bernat.ch/en/blog/2024-caddy-nix-plugins
{ pkgs, ... }:
let
  inherit (pkgs)
    buildGoModule
    cacert
    caddy
    go
    lib
    stdenv
    xcaddy
    ;
in
caddy.override {
  buildGoModule =
    args:
    buildGoModule (
      args
      // {
        src = stdenv.mkDerivation rec {
          pname = "caddy-using-xcaddy-${xcaddy.version}";
          inherit (caddy) version;

          dontUnpack = true;
          dontFixup = true;

          nativeBuildInputs = [
            cacert
            go
          ];

          plugins = [
            "github.com/WeidiDeng/caddy-cloudflare-ip"
          ];

          configurePhase = ''
            export GOCACHE=$TMPDIR/go-cache
            export GOPATH="$TMPDIR/go"
            export XCADDY_SKIP_BUILD=1
          '';

          buildPhase = ''
            ${xcaddy}/bin/xcaddy build "${caddy.src.rev}" ${
              lib.concatMapStringsSep " " (plugin: "--with ${plugin}") plugins
            }
            cd buildenv*
            go mod vendor
          '';

          installPhase = ''
            cp -r --reflink=auto . $out
          '';

          outputHash = "sha256-O3QWqgQtLOifsibyB0/UKricEGAx/3NhSjGbgu8+qgY=";
          outputHashMode = "recursive";
        };

        subPackages = [ "." ];
        ldflags = [
          "-s"
          "-w"
        ]; # # don't include version info twice
        vendorHash = null;
      }
    );
}
