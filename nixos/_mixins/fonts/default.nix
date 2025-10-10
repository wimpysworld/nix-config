{
  pkgs,
  ...
}:
{
  fonts = {
    fontDir.enable = true;
    packages = with pkgs; [
      nerd-fonts.fira-code
      noto-fonts-monochrome-emoji
      symbola
      work-sans
    ];
    fontconfig = {
      antialias = true;
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
