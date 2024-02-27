{ config, lib, pkgs, username, ... }:
with lib.hm.gvariant;
{
  imports = [
    ../../desktop/chatterino2.nix
    ../../desktop/discord.nix
    ../../desktop/gitkraken.nix
    #../../desktop/localsend.nix
    ../../desktop/meld.nix
    ../../desktop/nheko.nix
    ../../desktop/rhythmbox.nix
    ../../desktop/sakura.nix
    ../../desktop/vscode.nix
  ];
}
