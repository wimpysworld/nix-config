{ lib, pkgs, ... }:
{
  # Create a bootable ISO image with bcachefs.
  # - https://nixos.wiki/wiki/Bcachefs
  boot = {
    kernelPackages = lib.mkOverride 0 pkgs.linuxPackages_latest;
    supportedFilesystems = [ "bcachefs" ];
  };
  environment.systemPackages = with pkgs; [
    unstable.bcachefs-tools
    keyutils
  ];
}
