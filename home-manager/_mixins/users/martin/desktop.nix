{ config, lib, pkgs, username, ... }:
let
  inherit (pkgs.stdenv) isLinux;
in
with lib.hm.gvariant;
{
  imports = [
    ../../desktop/audio-recorder.nix
    ../../desktop/celluloid.nix
    ../../desktop/chatterino2.nix
    ../../desktop/dconf-editor.nix
    ../../desktop/discord.nix
    ../../desktop/emote.nix
    ../../desktop/gitkraken.nix
    ../../desktop/gnome-sound-recorder.nix
    ../../desktop/iterm2.nix
    ../../desktop/localsend.nix
    ../../desktop/meld.nix
    ../../desktop/nheko.nix
    ../../desktop/pick-colour-picker.nix
    ../../desktop/pika.nix
    ../../desktop/rhythmbox.nix
    ../../desktop/sakura.nix
    ../../desktop/tilix.nix
    ../../desktop/utm.nix
  ];

  # Authrorize X11 access in Distrobox
  home.file.".distroboxrc" = lib.mkIf isLinux {
    text = ''
      xhost +si:localuser:$USER
    '';
  };
}
