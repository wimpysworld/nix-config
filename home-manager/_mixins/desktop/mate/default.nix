{ config, lib, pkgs, ... }:
{
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
      configLocation = "${config.xdg.configHome}/.gtkrc-2.0";
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
  };

  home.pointerCursor = {
    name = "Yaru";
    package = pkgs.yaru-theme;
    size = 32;
    gtk.enable = true;
    x11.enable = true;
  };

  services = {
    gpg-agent.pinentryPackage = lib.mkForce pkgs.gcr;
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
