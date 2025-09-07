{
  pkgs,
  ...
}:
{
  # hyprpicker is a color picker for Hyprland
  home = {
    packages = with pkgs; [
      hyprpicker
    ];
  };
}
