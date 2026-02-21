{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
in
lib.mkIf (!host.is.iso) {
  environment.systemPackages =
    with pkgs;
    lib.optionals host.is.workstation [
      yubioath-flutter
    ];
  programs.yubikey-touch-detector.enable = host.is.workstation;
  programs.yubikey-touch-detector.libnotify = host.is.workstation;
  #security.pam.u2f.enable = true;
  #security.pam.yubico.control = "required";
  services = {
    udev.packages = [ pkgs.yubikey-personalization ];
    pcscd.enable = true;
  };
}
