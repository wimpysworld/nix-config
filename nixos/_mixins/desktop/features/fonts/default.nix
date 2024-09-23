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
        noto-fonts-monochrome-emoji
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
          "FiraCode Nerd Font Mono"
          "Font Awesome 6 Free"
          "Font Awesome 6 Brands"
          "Symbola"
          "Noto Emoji"
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
      localConf = ''
        <?xml version="1.0"?>
        <!DOCTYPE fontconfig SYSTEM "fonts.dtd">
        <fontconfig>
          <!-- Use Noto Emoji when other popular fonts are being specifically requested. -->
          <match target="pattern">
            <test qual="any" name="family"><string>Segoe UI Symbol</string></test>
            <edit name="family" mode="assign" binding="same"><string>Noto Emoji</string></edit>
          </match>
          <match target="pattern">
            <test qual="any" name="family"><string>EmojiSymbols</string></test>
            <edit name="family" mode="assign" binding="same"><string>Noto Emoji</string></edit>
          </match>
          <!-- This adds Noto Emoji as a final fallback font for Symbola. -->
          <match target="pattern">
            <test qual="any" name="family"><string>Symbola</string></test>
            <edit name="family" mode="append" binding="weak"><string>Noto Emoji</string></edit>
          </match>
          <!-- Use Noto Color Emoji when other popular fonts are being specifically requested. -->
          <match target="pattern">
            <test qual="any" name="family"><string>Apple Color Emoji</string></test>
            <edit name="family" mode="assign" binding="same"><string>Noto Color Emoji</string></edit>
          </match>
          <match target="pattern">
            <test qual="any" name="family"><string>Segoe UI Emoji</string></test>
            <edit name="family" mode="assign" binding="same"><string>Noto Color Emoji</string></edit>
          </match>
          <match target="pattern">
            <test qual="any" name="family"><string>Android Emoji</string></test>
            <edit name="family" mode="assign" binding="same"><string>Noto Color Emoji</string></edit>
          </match>
          <match target="pattern">
            <test qual="any" name="family"><string>Twitter Color Emoji</string></test>
            <edit name="family" mode="assign" binding="same"><string>Noto Color Emoji</string></edit>
          </match>
          <match target="pattern">
            <test qual="any" name="family"><string>Twemoji</string></test>
            <edit name="family" mode="assign" binding="same"><string>Noto Color Emoji</string></edit>
          </match>
          <match target="pattern">
            <test qual="any" name="family"><string>Twemoji Mozilla</string></test>
            <edit name="family" mode="assign" binding="same"><string>Noto Color Emoji</string></edit>
          </match>
          <match target="pattern">
            <test qual="any" name="family"><string>TwemojiMozilla</string></test>
            <edit name="family" mode="assign" binding="same"><string>Noto Color Emoji</string></edit>
          </match>
          <match target="pattern">
            <test qual="any" name="family"><string>EmojiTwo</string></test>
            <edit name="family" mode="assign" binding="same"><string>Noto Color Emoji</string></edit>
          </match>
          <match target="pattern">
            <test qual="any" name="family"><string>Emoji Two</string></test>
            <edit name="family" mode="assign" binding="same"><string>Noto Color Emoji</string></edit>
          </match>
        </fontconfig>
      '';
      subpixel = {
        rgba = "rgb";
        lcdfilter = "light";
      };
    };
  };
}
