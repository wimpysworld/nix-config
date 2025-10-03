{
  config,
  ...
}:
{
  catppuccin.micro.enable = config.programs.micro.enable;

  # Force true color detection for micro editor
  # Requires COLORTERM=truecolor too, which is set in home-manager/default.nix
  # https://github.com/zyedidia/micro/issues/3326#issuecomment-2148918654
  home.sessionVariables = {
    MICRO_TRUECOLOR = "1";
  };

  programs = {
    micro = {
      enable = true;
      settings = {
        autosu = true;
        diffgutter = true;
        paste = true;
        rmtrailingws = true;
        savecursor = true;
        saveundo = true;
        scrollbar = true;
        scrollbarchar = "┇";
        scrollmargin = 4;
        scrollspeed = 1;
        truecolor = true;
      };
    };
  };

  xdg = {
    desktopEntries = {
      micro = {
        name = "Micro";
        noDisplay = true;
      };
    };
  };
}
