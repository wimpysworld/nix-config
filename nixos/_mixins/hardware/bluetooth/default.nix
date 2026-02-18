{
  config,
  lib,
  pkgs,
  ...
}:
{
  environment.systemPackages = lib.optionals (!config.noughty.host.is.iso) [
    pkgs.bluetui
  ];
  hardware = {
    # https://nixos.wiki/wiki/Bluetooth
    bluetooth = {
      enable = !config.noughty.host.is.iso;
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
