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
        local-fonts.bebas-neue-2014-font
        local-fonts.bebas-neue-pro-font
        local-fonts.bebas-neue-rounded-font
        local-fonts.bebas-neue-semi-rounded-font
        local-fonts.boycott-font
        local-fonts.commodore-64-pixelized-font
        local-fonts.digital-7-font
        local-fonts.dirty-ego-font
        local-fonts.fixedsys-core-font
        local-fonts.fixedsys-excelsior-font
        local-fonts.impact-label-font
        local-fonts.mocha-mattari-font
        local-fonts.poppins-font
        local-fonts.spaceport-2006-font
        local-fonts.zx-spectrum-7-font
        ubuntu_font_family
        unscii
      ];

    fontconfig = {
      antialias = true;
      # Enable 32-bit support
      cache32Bit = lib.mkForce config.hardware.graphics.enable32Bit;
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
