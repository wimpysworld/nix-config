{ config, lib, pkgs, ... }:
{
  imports = [
    ./celluloid.nix
    ./dconf-editor.nix
    ./gnome-sound-recorder.nix
    ./gnome-text-editor.nix
    ./tilix.nix
  ];

  gtk = {
    enable = true;
    cursorTheme = {
      name = "elementary";
      package = pkgs.pantheon.elementary-icon-theme;
      size = 32;
    };

    font = {
      name = "Work Sans 12";
      package = pkgs.work-sans;
    };

    gtk2 = {
      configLocation = "${config.xdg.configHome}/gtk-2.0/gtkrc";
      extraConfig = ''
        gtk-application-prefer-dark-theme = 1
        gtk-decoration-layout = ":minimize,maximize,close"
        gtk-enable-primary-paste = true
      '';
    };

    gtk3 = {
      extraConfig = {
        gtk-application-prefer-dark-theme = 1;
        gtk-decoration-layout = ":minimize,maximize,close";
        gtk-enable-primary-paste = true;
      };
    };

    gtk4 = {
      extraConfig = {
        gtk-application-prefer-dark-theme = 1;
        gtk-decoration-layout = ":minimize,maximize,close";
        gtk-enable-primary-paste = true;
      };
    };

    iconTheme = {
      name = "elementary";
      package = pkgs.pantheon.elementary-icon-theme;
    };

    theme = {
      name = "io.elementary.stylesheet.bubblegum";
      package = pkgs.pantheon.elementary-gtk-theme;
    };
  };

  home.pointerCursor = {
    package = pkgs.pantheon.elementary-icon-theme;
    name = "elementary";
    size = 32;
    gtk.enable = true;
    x11.enable = true;
  };

  home.file = {
    "${config.xdg.configHome}/autostart/ibus-daemon.desktop".text = "
[Desktop Entry]
Name=IBus Daemon
Comment=IBus Daemon
Type=Application
Exec=${pkgs.ibus}/bin/ibus-daemon --daemonize --desktop=pantheon --replace --xim
Categories=
Terminal=false
NoDisplay=true
StartupNotify=false";

    "${config.xdg.configHome}/autostart/monitor.desktop".text = "
[Desktop Entry]
Name=Monitor Indicators
Comment=Monitor Indicators
Type=Application
Exec=/run/current-system/sw/bin/com.github.stsdc.monitor --start-in-background
Icon=com.github.stsdc.monitor
Categories=
Terminal=false
StartupNotify=false";
  };

  services = {
    gpg-agent.pinentryFlavor = lib.mkForce "gnome3";
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

  xdg = {
    desktopEntries = {
      # The usbimager icon path is hardcoded, so override the desktop file
      usbimager = {
        name = "USBImager";
        exec = "${pkgs.usbimager}/bin/usbimager";
        terminal = false;
        icon = "usbimager";
        type = "Application";
        categories = [ "System" "Application" ];
      };
    };
  };
}
