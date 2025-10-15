{
  config,
  desktop,
  isISO,
  isWorkstation,
  lib,
  pkgs,
  username,
  ...
}:
let
  isWorkstationISO = isISO && isWorkstation;
in
{
  config.users.users.nixos.description = "NixOS";

  # All configurations for live media are below:
  config.system = lib.mkIf isISO { stateVersion = lib.mkForce lib.trivial.release; };

  config.environment = {
    systemPackages = lib.optionals isWorkstationISO [ pkgs.gparted ];
  };

  # All workstation configurations for live media are below.
  config.isoImage = lib.mkIf isWorkstationISO { edition = lib.mkForce "${desktop}"; };

  config.services = {
    displayManager.autoLogin = lib.mkIf isWorkstationISO { user = "${username}"; };
  };

  # Create desktop shortcuts and dock items for the live media
  config.systemd.tmpfiles = lib.mkIf isWorkstationISO {
    rules = [
      "d /home/${username}/Desktop 0755 ${username} users"
      "d /home/${username}/.config 0755 ${username} users"
      "L+ /home/${username}/Desktop/io.calamares.calamares.desktop - - - - ${pkgs.calamares-nixos}/share/applications/io.calamares.calamares.desktop"
      "L+ /home/${username}/Desktop/gparted.desktop - - - - ${pkgs.gparted}/share/applications/gparted.desktop"
    ];
  };
}
