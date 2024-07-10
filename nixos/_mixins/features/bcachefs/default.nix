{ hostname, lib, pkgs, ... }:
let
  installOn = [ "minimech" "scrubber" "sidious" ];
  isISO = builtins.substring 0 4 hostname == "iso-";
in
lib.mkIf (lib.elem hostname installOn || isISO) {
  # Create a bootable ISO image with bcachefs.
  # - https://wiki.nixos.org/wiki/Bcachefs
  boot = {
    kernelPackages = lib.mkOverride 0 pkgs.linuxPackages_latest;
    supportedFilesystems = [ "bcachefs" ];
  };
  environment.systemPackages = with pkgs; [
    bcachefs-tools
    keyutils
  ];
}
