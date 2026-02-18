{
  config,
  lib,
  noughtyLib,
  options,
  pkgs,
  ...
}:
let
  isNixosUser = noughtyLib.isUser [ "nixos" ];
  username = config.noughty.user.name;
  isWorkstationISO = config.noughty.host.is.iso && config.noughty.host.is.workstation;
in
{
  config = lib.mkIf isNixosUser (
    lib.mkMerge [
      {
        users.users.nixos.description = "NixOS";

        # All configurations for live media are below:
        system = lib.mkIf config.noughty.host.is.iso {
          stateVersion = lib.mkForce lib.trivial.release;
        };

        environment = {
          systemPackages = lib.optionals isWorkstationISO [ pkgs.gparted ];
        };

        services = {
          displayManager.autoLogin = lib.mkIf isWorkstationISO { user = "${username}"; };
        };

        # Create desktop shortcuts and dock items for the live media
        systemd.tmpfiles = lib.mkIf isWorkstationISO {
          rules = [
            "d /home/${username}/Desktop 0755 ${username} users"
            "d /home/${username}/.config 0755 ${username} users"
            "L+ /home/${username}/Desktop/io.calamares.calamares.desktop - - - - ${pkgs.calamares-nixos}/share/applications/io.calamares.calamares.desktop"
            "L+ /home/${username}/Desktop/gparted.desktop - - - - ${pkgs.gparted}/share/applications/gparted.desktop"
          ];
        };
      }
      # isoImage is only declared by the ISO image module; use optionalAttrs
      # with an option existence check to avoid errors on non-ISO hosts.
      (lib.optionalAttrs (options ? isoImage) {
        isoImage = lib.mkIf isWorkstationISO {
          edition = lib.mkForce "${config.noughty.host.desktop}";
        };
      })
    ]
  );
}
