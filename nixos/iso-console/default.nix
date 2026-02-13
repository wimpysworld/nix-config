{ lib, pkgs, ... }:
{
  # Use the default kernel for the ISO instead of the pinned kernel from nixos/default.nix
  boot.kernelPackages = lib.mkForce pkgs.linuxPackages;

  nixpkgs.overlays = [
    (_final: super: {
      # Prevent mbrola-voices (~650MB) from being on the live media
      espeak = super.espeak.override { mbrolaSupport = false; };
    })
  ];
}
