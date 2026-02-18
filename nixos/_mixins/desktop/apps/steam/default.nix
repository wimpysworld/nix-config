{
  config,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
lib.mkIf
  (noughtyLib.isHost [
    "phasma"
    "vader"
  ])
  {
    # Only include mangohud if Steam is enabled
    environment.systemPackages = with pkgs; lib.mkIf config.programs.steam.enable [ mangohud ];
    # https://nixos.wiki/wiki/Steam
    programs = {
      steam = {
        enable = true;
        remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
        dedicatedServer.openFirewall = true; # Open ports in the firewall for Source Dedicated Server
      };
    };
  }
