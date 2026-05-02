{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  bluetuiDesktopEntry = pkgs.writeText "bluetui.desktop" ''
    [Desktop Entry]
    Name=Bluetui
    GenericName=Bluetooth Manager
    Comment=Manage bluetooth devices
    Exec=bluetui
    Terminal=true
    Type=Application
    Keywords=bluetooth
    Categories=Utility;Settings;ConsoleOnly
    StartupNotify=false
    NoDisplay=true
  '';
  bluetui = pkgs.symlinkJoin {
    name = "bluetui-hidden";
    paths = [ pkgs.bluetui ];
    postBuild = ''
      rm -f $out/share/applications/bluetui.desktop
      install -Dm444 ${bluetuiDesktopEntry} $out/share/applications/bluetui.desktop
    '';
  };
in
{
  environment = {
    systemPackages = lib.optionals (!host.is.iso) [
      bluetui
    ];
  };
  hardware = {
    # https://nixos.wiki/wiki/Bluetooth
    bluetooth = {
      enable = !host.is.iso;
      package = pkgs.bluez;
      settings = {
        General = {
          Enable = "Source,Sink,Media,Socket";
          Experimental = true;
        };
      };
    };
  };
}
