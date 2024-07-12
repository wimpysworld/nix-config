{
  config,
  hostname,
  lib,
  pkgs,
  ...
}:
let
  installOn = [
    "phasma"
    "vader"
  ];
in
lib.mkIf (lib.elem hostname installOn) {
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
