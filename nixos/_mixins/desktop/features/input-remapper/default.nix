{
  isInstall,
  lib,
  ...
}:
lib.mkIf isInstall {
  services = {
    input-remapper = {
      enable = true;
    };
  };
}
