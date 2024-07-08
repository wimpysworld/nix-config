{ config, desktop, hostname, lib, pkgs, ... }:
let
  isGamestation = if (hostname == "phasma" || hostname == "vader") && (desktop != null) then true else false;
in
lib.mkIf (isGamestation) {
  # Only include mangohud if Steam is enabled
  environment.systemPackages = with pkgs; lib.mkIf (config.programs.steam.enable) [
    mangohud
  ];
  # https://nixos.wiki/wiki/Steam
  programs = {
    steam = {
      enable = true;
      remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
      dedicatedServer.openFirewall = true; # Open ports in the firewall for Source Dedicated Server
    };
  };
}
