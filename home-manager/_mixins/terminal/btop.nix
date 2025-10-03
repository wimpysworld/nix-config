{
  config,
  pkgs,
  ...
}:
{
  catppuccin.btop.enable = config.programs.btop.enable;

  programs = {
    btop = {
      enable = true;
      package = pkgs.btop.override {
        cudaSupport = true;
        rocmSupport = true;
      };
    };
  };

  xdg = {
    desktopEntries = {
      btop = {
        name = "btop++";
        noDisplay = true;
      };
    };
  };
}
