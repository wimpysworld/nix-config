{
  hostname,
  isISO,
  lib,
  pkgs,
  ...
}:
let
  installOn = [
    "shaa"
    "sidious"
  ];
in
lib.mkIf (lib.elem hostname installOn || isISO) {
  # Bootable ISO images include bcachefs tools
  # - https://wiki.nixos.org/wiki/Bcachefs
  environment.systemPackages = with pkgs; [
    bcachefs-tools
    keyutils
  ];
}
