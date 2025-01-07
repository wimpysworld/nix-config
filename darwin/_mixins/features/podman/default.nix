{
  lib,
  pkgs,
  ...
}:
{
  environment.systemPackages = with pkgs; [
    act
    podman
  ];

  homebrew = {
    casks = [ "podman-desktop" ];
  };
}
