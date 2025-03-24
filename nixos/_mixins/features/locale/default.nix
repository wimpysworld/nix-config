{ config, hostname, lib, ... }:
let
  locale = "en_GB.utf8";
  xkbLayout = if (hostname == "phasma" || hostname == "vader") then "us" else "gb";
in
{
  console = lib.mkIf (config.console.font != null) {
    useXkbConfig =  true;
  };
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
      useXkbConfig = true;
    };
    xserver.xkb.layout = xkbLayout;
  };
}
