{
  hostname,
  isISO,
  lib,
  pkgs,
  ...
}:
let
  installOn = [
    "crawler"
    "dagger"
    "shaa"
    "sidious"
  ];
in
lib.mkIf (lib.elem hostname installOn || isISO) {
  # Create a bootable ISO image with bcachefs.
  # - https://wiki.nixos.org/wiki/Bcachefs
  boot = {
    kernelPackages = lib.mkOverride 0 pkgs.linuxPackages_6_12;
    supportedFilesystems = [ "bcachefs" ];
  };
  environment.systemPackages = with pkgs; [
    bcachefs-tools
    keyutils
  ];
}
