{ lib, pkgs, ... }:
{
  # Create a bootable ISO image with bcachefs.
  # - https://nixos.wiki/wiki/Bcachefs
  boot.supportedFilesystems = [ "bcachefs" ];
  boot.kernelPackages = lib.mkOverride 0 pkgs.linuxPackages_latest;
  environment.systemPackages = with pkgs; [
    unstable.bcachefs-tools
    keyutils
  ];
}
