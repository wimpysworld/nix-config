{ config, lib, ... }:
let
  locale = "en_GB.utf8";
  xkbLayout = "gb";
in
{
  console.keyMap = lib.mkIf (config.console.font != null) "uk";
  i18n = {
    defaultLocale = locale;
    extraLocaleSettings = {
      LC_ADDRESS = locale;
      LC_IDENTIFICATION = locale;
      LC_MEASUREMENT = locale;
      LC_MONETARY = locale;
      LC_NAME = locale;
      LC_NUMERIC = locale;
      LC_PAPER = locale;
      LC_TELEPHONE = locale;
      LC_TIME = locale;
    };
  };

  services = {
    kmscon = lib.mkIf config.services.kmscon.enable {
      extraConfig = ''
        xkb-layout=${xkbLayout}
      '';
    };
    xserver.xkb.layout = xkbLayout;
  };
}
