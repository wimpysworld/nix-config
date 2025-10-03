{
  config,
  ...
}:
{
  catppuccin.cava.enable = config.programs.cava.enable;

  programs = {
    cava = {
      enable = true;
    };
  };
}
