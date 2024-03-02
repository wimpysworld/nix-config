{ config, lib, pkgs, ... }:
{
  imports = [
    ./gnome-sound-recorder.nix
  ];

  gtk = {
    enable = true;
    cursorTheme = {
      name = "Yaru";
      package = pkgs.yaru-theme;
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
      '';
    };

    gtk3 = {
      extraConfig = {
        gtk-application-prefer-dark-theme = 1;
      };
    };

    gtk4 = {
      extraConfig = {
        gtk-application-prefer-dark-theme = 1;
      };
    };

    iconTheme = {
      name = "Yaru-blue-dark";
      package = pkgs.yaru-theme;
    };

    theme = {
      name = "Yaru-blue-dark";
      package = pkgs.yaru-theme;
    };
  };

  home.pointerCursor = {
    name = "Yaru";
    package = pkgs.yaru-theme;
    size = 32;
    gtk.enable = true;
    x11.enable = true;
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
