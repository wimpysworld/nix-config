{ config, lib, pkgs, username, ... }:
{
  imports = [
    ../../desktop/chatterino2.nix
    ../../desktop/discord.nix
    ../../desktop/gitkraken.nix
    #../../desktop/localsend.nix
    ../../desktop/meld.nix
    ../../desktop/rhythmbox.nix
    ../../desktop/sakura.nix
    ../../desktop/vscode.nix
  ];

  # User specific dconf settings; only intended as override for NixOS dconf profile user database
  dconf.settings = with lib.hm.gvariant; {
    #"com/github/stsdc/monitor/settings" = {
    #  background-state = true;
    #};
  };
}
