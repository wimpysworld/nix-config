{
  config,
  isInstall,
  lib,
  pkgs,
  ...
}:
{
  # https://yildiz.dev/posts/packing-custom-fonts-for-nixos/
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
        font-awesome
        liberation_ttf
        noto-fonts-emoji
        source-serif
        symbola
        work-sans
      ]
      ++ lib.optionals isInstall [
        bebas-neue-2014-font
        bebas-neue-pro-font
        bebas-neue-rounded-font
        bebas-neue-semi-rounded-font
        boycott-font
        commodore-64-pixelized-font
        digital-7-font
        dirty-ego-font
        fixedsys-core-font
        fixedsys-excelsior-font
        impact-label-font
        mocha-mattari-font
        poppins-font
        spaceport-2006-font
        ubuntu_font_family
        unscii
        zx-spectrum-7-font
      ];

    fontconfig = {
      antialias = true;
      # Enable 32-bit support if driSupport32Bit is true
      cache32Bit = lib.mkForce config.hardware.opengl.driSupport32Bit;
      defaultFonts = {
        serif = [
          "Source Serif"
          "Noto Color Emoji"
        ];
        sansSerif = [
          "Work Sans"
          "Fira Sans"
          "Noto Color Emoji"
        ];
        monospace = [
          "Symbols Nerd Font Mono"
          "Font Awesome 6 Free"
          "Font Awesome 6 Brands"
          "Symbola"
        ];
        emoji = [
          "Noto Color Emoji"
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
