{
  config,
  isInstall,
  lib,
  pkgs,
  ...
}:
{
  fonts = {
    # Enable a basic set of fonts providing several font styles and families and reasonable coverage of Unicode.
    enableDefaultPackages = false;
    fontDir.enable = true;
    packages =
      with pkgs;
      [
        (nerdfonts.override {
          fonts = [
            "FiraCode"
            "NerdFontsSymbolsOnly"
          ];
        })
        fira
        liberation_ttf
        noto-fonts-emoji
        source-serif
        symbola
        work-sans
      ]
      ++ lib.optionals isInstall [
        ubuntu_font_family
        twitter-color-emoji
      ];

    fontconfig = {
      antialias = true;
      # Enable 32-bit support if driSupport32Bit is true
      cache32Bit = lib.mkForce config.hardware.opengl.driSupport32Bit;
      defaultFonts = {
        serif = [ "Source Serif" ];
        sansSerif = [
          "Work Sans"
          "Fira Sans"
        ];
        monospace = [
          "FiraCode Nerd Font Mono"
          "Symbols Nerd Font Mono"
        ];
        emoji = [
          "Noto Color Emoji"
          "Twitter Color Emoji"
        ];
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
}
