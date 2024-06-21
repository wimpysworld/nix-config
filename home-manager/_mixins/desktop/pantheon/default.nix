{ config, lib, pkgs, ... }:
{
  home.file = {
    "${config.xdg.configHome}/autostart/monitor.desktop".text = ''
[Desktop Entry]
Name=Monitor Indicators
Comment=Monitor Indicators
Type=Application
Exec=/run/current-system/sw/bin/com.github.stsdc.monitor --start-in-background
Icon=com.github.stsdc.monitor
Categories=
Terminal=false
StartupNotify=false'';
    ".local/share/applications/io.elementary.files.desktop".text = ''
[Desktop Entry]
Name=Files
Comment=Browse your files
Keywords=folder;manager;explore;disk;filesystem;
GenericName=File Manager
Exec=io.elementary.files %U
Icon=system-file-manager
NoDisplay=true
Terminal=false
StartupNotify=true
Type=Application
MimeType=inode/directory;
Categories=System;'';
    ".local/share/applications/caja.desktop".text = ''
[Desktop Entry]
Name=Caja
Comment=Browse your files
Keywords=folder;manager;explore;disk;filesystem;
GenericName=File Manager
Exec=caja --no-desktop
Icon=system-file-manager
Terminal=false
StartupNotify=true
Type=Application
MimeType=inode/directory;
Categories=System;'';
  };

  services = {
    gpg-agent.pinentryPackage = lib.mkForce pkgs.pinentry-gnome3;
    # https://nixos.wiki/wiki/Bluetooth#Using_Bluetooth_headsets_with_PulseAudio
    mpris-proxy.enable = true;
  };

  systemd.user.services = {
    # https://github.com/tom-james-watson/emote
    emote = {
      Unit = {
        Description = "Emote";
      };
      Service = {
        ExecStart = "${pkgs.emote}/bin/emote";
        Restart = "on-failure";
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
    };
  };
}
