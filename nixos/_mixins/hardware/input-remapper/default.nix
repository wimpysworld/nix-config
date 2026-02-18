{
  config,
  hostname,
  lib,
  pkgs,
  username,
  ...
}:
let
  enableInputRemapper = hostname == "phasma" || hostname == "vader";
in
lib.mkIf (!config.noughty.host.is.iso) {
  services.input-remapper = {
    enable = enableInputRemapper;
    enableUdevRules = enableInputRemapper;
  };

  # Autoload input-remapper profiles as system service (active at login screen)
  systemd.services.input-remapper-autoload = lib.mkIf enableInputRemapper {
    description = "Autoload input-remapper profile";
    after = [ "input-remapper.service" ];
    before = [ "display-manager.service" ];
    wantedBy = [ "graphical.target" ];
    script = ''
      ${pkgs.input-remapper}/bin/input-remapper-control --command stop-all
      ${pkgs.input-remapper}/bin/input-remapper-control --command autoload
    '';
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
  };

  # Link user's input-remapper config to root so autoload works for hotplugged devices
  systemd.tmpfiles.rules = lib.mkIf enableInputRemapper [
    "d /home/${username}/.config/input-remapper-2 0755 ${username} users"
    "L+ /root/.config/input-remapper-2 - - - - /home/${username}/.config/input-remapper-2"
  ];
}
