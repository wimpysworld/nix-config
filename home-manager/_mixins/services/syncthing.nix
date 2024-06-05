{ config, desktop, hostname, lib, pkgs, username, ... }:
let
  isWorkstation = if (desktop != null) then true else false;
in
{
  home.packages = with pkgs; [
    stc-cli
  ];
  imports = lib.optionals (isWorkstation) [
    ./syncthing-tray.nix
  ];
  programs.fish.shellAliases = {
    stc = "${pkgs.stc-cli}/bin/stc -homedir \"${config.home.homeDirectory}/Syncthing/Devices/${hostname}\"";
  };
  services.syncthing = {
    enable = true;
    extraOptions = [
      "--config=${config.home.homeDirectory}/Syncthing/Devices/${hostname}"
      "--data=${config.home.homeDirectory}/Syncthing/DB/${hostname}"
      "--gui-address=${hostname}.drongo-gamma.ts.net:8384"
      "--no-default-folder"
      "--no-browser"
    ];
  };
  sops = {
    # sops-nix options: https://dl.thalheim.io/
    secrets = {
      syncthing_apikey = {};
      syncthing_user = {};
      syncthing_pass = {};
    };
  };
}
