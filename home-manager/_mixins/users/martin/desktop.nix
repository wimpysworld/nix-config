{ config, lib, pkgs, username, ... }:
let
  inherit (pkgs.stdenv) isLinux;
in
with lib.hm.gvariant;
{
  imports = [
    ../../desktop/chatterino2.nix
    ../../desktop/discord.nix
    ../../desktop/gitkraken.nix
    ../../desktop/iterm2.nix
    #../../desktop/localsend.nix
    ../../desktop/meld.nix
    ../../desktop/nheko.nix
    ../../desktop/pika.nix
    ../../desktop/rhythmbox.nix
    ../../desktop/sakura.nix
    ../../desktop/utm.nix
    ../../desktop/vscode.nix
  ];

  # Authrorize X11 access in Distrobox
  home.file.".distroboxrc" = lib.mkIf isLinux {
    text = ''
      xhost +si:localuser:$USER
    '';
  };
}
