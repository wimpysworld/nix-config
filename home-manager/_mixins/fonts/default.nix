{
  isWorkstation,
  lib,
  pkgs,
  ...
}:
{
  home = {
    file.".config/fontconfig/fonts.conf".text = ''
      <?xml version="1.0"?>
      <!DOCTYPE fontconfig SYSTEM "fonts.dtd">
      <fontconfig>
        <match target="font">
          <edit name="antialias" mode="assign">
            <bool>true</bool>
          </edit>
          <edit name="hinting" mode="assign">
            <bool>true</bool>
          </edit>
          <edit name="hintstyle" mode="assign">
            <const>hintslight</const>
          </edit>
          <edit name="rgba" mode="assign">
            <const>rgb</const>
          </edit>
          <edit name="lcdfilter" mode="assign">
            <const>lcddefault</const>
          </edit>
        </match>
      </fontconfig>
    '';
    packages =
      with pkgs;
      [
        nerd-fonts.fira-code
        font-awesome
        noto-fonts-emoji
        noto-fonts-monochrome-emoji
        symbola
        work-sans
      ]
      ++ lib.optionals isWorkstation [
        bebas-neue-2014-font
        bebas-neue-pro-font
        bebas-neue-rounded-font
        bebas-neue-semi-rounded-font
        bw-fusiona-font
        boycott-font
        commodore-64-pixelized-font
        corefonts
        digital-7-font
        dirty-ego-font
        fira-go
        fira-sans
        fixedsys-core-font
        fixedsys-excelsior-font
        impact-label-font
        lato
        liberation_ttf
        mocha-mattari-font
        nerd-fonts.space-mono
        nerd-fonts.symbols-only
        poppins-font
        source-serif
        spaceport-2006-font
        ubuntu_font_family
        unscii
        zx-spectrum-7-font
      ];
  };

  fonts = {
    fontconfig = {
      enable = true;
      defaultFonts = {
        serif = [
          "Source Serif"
          "Noto Color Emoji"
        ];
        sansSerif = [
          "Work Sans"
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
    };
  };
}
