{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
in
lib.mkIf (!host.is.iso && !host.is.server) {
  #security.pam.u2f.enable = true;
  #security.pam.yubico.control = "required";
  services = {
    udev.packages = [ pkgs.yubikey-personalization ];
    pcscd.enable = true;
  };
}
