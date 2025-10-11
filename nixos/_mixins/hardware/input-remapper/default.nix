{
  hostname,
  isInstall,
  lib,
  ...
}:
lib.mkIf isInstall {
  services = {
    input-remapper = {
      enable = hostname == "phasma" || hostname == "vader";
    };
  };
}
