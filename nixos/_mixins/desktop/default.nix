{ desktop, lib, pkgs, ... }: {
  imports = [
    ../services/cups.nix
    ../services/flatpak.nix
    ../services/networkmanager.nix
    ../services/sane.nix
  ]
  ++ lib.optional (builtins.pathExists (./. + "/${desktop}.nix")) ./${desktop}.nix;

  boot = {
    kernelParams = [ "quiet" "vt.global_cursor_default=0" "mitigations=off" ];
    plymouth = {
      enable = true;
    };
  };

  fonts = {
    # Enable a basic set of fonts providing several font styles and families and reasonable coverage of Unicode.
    enableDefaultPackages = false;
    fontDir.enable = true;
    packages = with pkgs; [
      (nerdfonts.override { fonts = [ "FiraCode" "SourceCodePro" "UbuntuMono" ]; })
      fira
      fira-go
      joypixels
      liberation_ttf
      noto-fonts-emoji
      source-serif
      ubuntu_font_family
      work-sans
    ];

    fontconfig = {
      antialias = true;
      defaultFonts = {
        serif = [ "Source Serif" ];
        sansSerif = [ "Work Sans" "Fira Sans" "FiraGO" ];
        monospace = [ "FiraCode Nerd Font Mono" "SauceCodePro Nerd Font Mono" ];
        emoji = [ "Joypixels" "Noto Color Emoji" ];
      };
      enable = true;
      hinting = {
        autohint = false;
        enable = true;
        style = "slight";
      };
      subpixel = {
        rgba = "rgb";
        lcdfilter = "light";
      };
    };
  };

  # Accept the joypixels license
  nixpkgs.config.joypixels.acceptLicense = true;

  hardware = {
    opengl = {
      enable = true;
      driSupport = true;
    };
  };

  programs.dconf.enable = true;

  # Disable xterm
  services.xserver.excludePackages = [ pkgs.xterm ];
  services.xserver.desktopManager.xterm.enable = false;

  # Disable autoSuspend; my Pantheon session kept auto-suspending
  # - https://discourse.nixos.org/t/why-is-my-new-nixos-install-suspending/19500
  services.xserver.displayManager.gdm.autoSuspend = false;
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
        if (action.id == "org.freedesktop.login1.suspend" ||
            action.id == "org.freedesktop.login1.suspend-multiple-sessions" ||
            action.id == "org.freedesktop.login1.hibernate" ||
            action.id == "org.freedesktop.login1.hibernate-multiple-sessions")
        {
            return polkit.Result.NO;
        }
    });
  '';

  xdg.portal = {
    config = {
      common = {
        default = [
          "gtk"
        ];
      };
      pantheon = {
        default = [
          "pantheon"
          "gtk"
        ];
        "org.freedesktop.impl.portal.Secret" = [
          "gnome-keyring"
        ];
      };
    };
    enable = true;
    xdgOpenUsePortal = true;
  };
}
