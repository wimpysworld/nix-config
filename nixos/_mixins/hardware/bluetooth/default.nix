{
  config,
  lib,
  pkgs,
  ...
}:
let
  host = config.noughty.host;
in
{
  environment = {
    systemPackages = lib.optionals (!host.is.iso) [
      pkgs.bluetui
    ];
    # Hide the bluetui desktop entry from application launchers; it's a TUI
    # tool intended to be launched from a terminal, not a launcher.
    etc."xdg/applications/bluetui.desktop".text = ''
      [Desktop Entry]
      Name=Bluetui
      NoDisplay=true
    '';
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
