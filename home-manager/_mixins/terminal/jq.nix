{
  config,
  ...
}:
{
  programs = {
    jq = {
      enable = true;
    };
    jqp = {
      enable = true;
      settings = {
        theme = {
          name = "catppuccin-${config.catppuccin.flavor}";
        };
      };
    };
  };
}
