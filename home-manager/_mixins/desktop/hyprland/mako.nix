{
  pkgs,
  ...
}:
{
  # mako is a notification daemon
  services = {
    mako = {
      actions = true;
      anchor = "top-right";
      borderRadius = 8;
      borderSize = 1;
      catppuccin.enable = true;
      enable = true;
      defaultTimeout = 10000;
      font = "Work Sans";
      iconPath = "${pkgs.papirus-icon-theme}/share/icons/Papirus-Dark";
      icons = true;
      layer = "overlay";
      maxVisible = 4;
      padding = "12";
      width = 320;
    };
  };
}
