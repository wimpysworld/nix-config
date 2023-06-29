{ desktop, lib, pkgs, ... }: {
  imports = [
    ./chromium.nix
    ../services/cups.nix
    ../services/flatpak.nix
    ../services/sane.nix
  ]
  ++ lib.optional (builtins.pathExists (./. + "/${desktop}.nix")) ./${desktop}.nix;

  boot.kernelParams = [
    # The 'splash' arg is included by the plymouth option
    "quiet"
    "loglevel=3"
    "rd.udev.log_priority=3"
    "vt.global_cursor_default=0"
    "mitigations=off"
  ];
  boot.plymouth.enable = true;

  fonts = {
    fontDir.enable = true;
    fonts = with pkgs; [
      (nerdfonts.override { fonts = [ "FiraCode" "UbuntuMono"]; })
      joypixels
      liberation_ttf
      ubuntu_font_family
      work-sans
    ];

    # use fonts specified by user rather than default ones
    enableDefaultFonts = false;

    fontconfig = {
      antialias = true;
      defaultFonts = {
        serif = [ "Work Sans" "Joypixels" ];
        sansSerif = [ "Work Sans" "Joypixels" ];
        monospace = [ "FiraCode Nerd Font Mono" ];
        emoji = [ "Joypixels" ];
      };
      enable = true;
      hinting = {
        autohint = false;
        enable = true;
        style = "hintslight";
      };
      subpixel = {
        rgba = "rgb";
        lcdfilter = "light";
      };
    };
  };

  programs = {
    dconf.enable = true;
    # Chromium is enabled by default with sane defaults.
    firefox = {
      enable = false;
    };
  };

  # Accept the joypixels license
  nixpkgs.config.joypixels.acceptLicense = true;
  
  # Disable xterm
  services.xserver.excludePackages = [ pkgs.xterm ];
  services.xserver.desktopManager.xterm.enable = false;
}
