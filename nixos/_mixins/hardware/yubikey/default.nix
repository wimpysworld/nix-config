{
  config,
  lib,
  pkgs,
  ...
}:
lib.mkIf (!config.noughty.host.is.iso) {
  environment.systemPackages =
    with pkgs;
    lib.optionals config.noughty.host.is.workstation [
      yubioath-flutter
    ];
  programs.yubikey-touch-detector.enable = config.noughty.host.is.workstation;
  programs.yubikey-touch-detector.libnotify = config.noughty.host.is.workstation;
  #security.pam.u2f.enable = true;
  #security.pam.yubico.control = "required";
  services = {
    udev.packages = [ pkgs.yubikey-personalization ];
    pcscd.enable = true;
  };
}
