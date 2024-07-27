{
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ./apps
    ./features
  ];

  environment.systemPackages =
    with pkgs;
    [ ];

  homebrew.masApps = {

  };
}
