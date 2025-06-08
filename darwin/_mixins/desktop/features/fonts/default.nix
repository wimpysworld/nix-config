{ pkgs, ... }:
{
  fonts = {
    packages = with pkgs; [
      nerd-fonts.fira-code
      nerd-fonts.fira-mono
      nerd-fonts.symbols-only
      corefonts
      fira
      font-awesome
      liberation_ttf
      noto-fonts-emoji
      noto-fonts-monochrome-emoji
      source-serif
      symbola
      work-sans
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
      lato
      mocha-mattari-font
      poppins-font
      spaceport-2006-font
      ubuntu_font_family
      unscii
      zx-spectrum-7-font
    ];
  };
}
