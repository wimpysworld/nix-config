{
  config,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
in
{
  hardware = {
    # https://nixos.wiki/wiki/Bluetooth
    bluetooth = {
      enable = host.is.workstation;
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
