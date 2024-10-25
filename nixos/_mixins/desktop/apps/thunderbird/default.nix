{
  lib,
  isInstall,
  pkgs,
  ...
}:
{
  environment = {
    systemPackages =
      with pkgs;
      lib.optionals isInstall [
        thunderbird
      ];
  };
}
