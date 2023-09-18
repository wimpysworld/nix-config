{ config, lib, pkgs, username, ... }:
with lib.hm.gvariant;
{
  imports = [
    ../../desktop/audio-recorder.nix
    ../../desktop/celluloid.nix
    ../../desktop/dconf-editor.nix
    ../../desktop/emote.nix
    ../../desktop/gitkraken.nix
    ../../desktop/gnome-sound-recorder.nix
    ../../desktop/localsend.nix
    ../../desktop/meld.nix
    ../../desktop/rhythmbox.nix
    ../../desktop/sakura.nix
    ../../desktop/tilix.nix
  ];

  dconf.settings = {
    "org/gnome/rhythmbox/rhythmdb" = {
      locations = [ "file://${config.home.homeDirectory}/Studio/Music" ];
      monitor-library = true;
    };
  };

  # Authrorize X11 access in Distrobox
  home.file.".distroboxrc".text = ''
    xhost +si:localuser:$USER
  '';
}
