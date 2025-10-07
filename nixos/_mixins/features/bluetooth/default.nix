{
  isInstall,
  lib,
  pkgs,
  ...
}:
{
  environment.systemPackages = lib.optionals isInstall [
    pkgs.bluetui
  ];
  hardware = {
    # https://nixos.wiki/wiki/Bluetooth
    bluetooth = {
      enable = isInstall;
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
