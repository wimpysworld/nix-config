{ lib, ... }:
{
  # The installer profile enables CIFS support, and cifs-utils drags the full
  # python3 interpreter (~126 MiB) into the closure. Installs never mount CIFS
  # shares, so drop it from the live media.
  boot.supportedFilesystems.cifs = lib.mkForce false;

  # Do not copy the nixpkgs source (~195 MiB) into the closure to serve the nix
  # path and flake registry; it would be a redundant third copy. The registry
  # pin from common/default.nix and the installer channel remain.
  nixpkgs.flake.setNixPath = false;
  nixpkgs.flake.setFlakeRegistry = false;

  nixpkgs.overlays = [
    (_final: super: {
      # Prevent mbrola-voices (~650MB) from being on the live media
      espeak = super.espeak.override { mbrolaSupport = false; };
    })
  ];
}
