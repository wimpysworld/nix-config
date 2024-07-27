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
    LastPass = 926036361;
  };
}
