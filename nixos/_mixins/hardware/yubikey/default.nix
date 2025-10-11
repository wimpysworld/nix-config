{
  isWorkstation,
  pkgs,
  ...
}:
{
  environment.systemPackages =
    with pkgs;
    lib.optionals isWorkstation [
      yubioath-flutter
    ];
  programs.yubikey-touch-detector.enable = isWorkstation;
  programs.yubikey-touch-detector.libnotify = isWorkstation;
  #security.pam.u2f.enable = true;
  #security.pam.yubico.control = "required";
  services = {
    udev.packages = [ pkgs.yubikey-personalization ];
    pcscd.enable = true;
  };
}
