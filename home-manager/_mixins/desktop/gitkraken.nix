{ pkgs, ... }:
{
  home.packages = with pkgs; [
    gitkraken
  ];
}
