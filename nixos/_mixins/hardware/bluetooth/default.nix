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
  environment.systemPackages = lib.optionals (!host.is.iso) [
    pkgs.bluetui
  ];
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
