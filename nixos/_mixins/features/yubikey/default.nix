{
  isWorkstation,
  pkgs,
  ...
}:
{
  environment.systemPackages = with pkgs; lib.optionals isWorkstation [
    yubioath-flutter
  ];
  programs.yubikey-touch-detector.enable = true;
  programs.yubikey-touch-detector.libnotify = true;
  #security.pam.u2f.enable = true;
  #security.pam.yubico.control = "required";
  services = {
    udev.packages = [ pkgs.yubikey-personalization ];
    pcscd.enable = true;
  };
}
