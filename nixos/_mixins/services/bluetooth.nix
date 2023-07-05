{ pkgs, ... }:
{
  # https://nixos.wiki/wiki/Bluetooth
  hardware.bluetooth = {
    enable = true;
    package = pkgs.pulseaudioFull;
    settings = {
      General = {
        Enable = "Source,Sink,Media,Socket";
      };
    };
  };
}
