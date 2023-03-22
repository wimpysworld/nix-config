{ config, desktop, lib, pkgs, username, ...}:
let
  ifExists = groups: builtins.filter (group: builtins.hasAttr group config.users.groups) groups;
in
{
   # Only include desktop components if one is supplied.
  imports = [
    ./packages-console.nix
  ] ++ lib.optional (builtins.isString desktop) ./packages-desktop.nix;

  config.users.users.nixos = {
    description = "NixOS";
    extraGroups = [
        "audio"
        "networkmanager"
        "users"
        "video"
        "wheel"
      ]
      ++ ifExists [
        "docker"
        "podman"
      ];
    openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAywaYwPN4LVbPqkc+kUc7ZVazPBDy4LCAud5iGJdr7g9CwLYoudNjXt/98Oam5lK7ai6QPItK6ECj5+33x/iFpWb3Urr9SqMc/tH5dU1b9N/9yWRhE2WnfcvuI0ms6AXma8QGp1pj/DoLryPVQgXvQlglHaDIL1qdRWFqXUO2u30X5tWtDdOoR02UyAtYBttou4K0rG7LF9rRaoLYP9iCBLxkMJbCIznPD/pIYa6Fl8V8/OVsxYiFy7l5U0RZ7gkzJv8iNz+GG8vw2NX4oIJfAR4oIk3INUvYrKvI2NSMSw5sry+z818fD1hK+soYLQ4VZ4hHRHcf4WV4EeVa5ARxdw== Martin Wimpress"
    ];
    packages = [ pkgs.home-manager ];
    shell = pkgs.fish;
  };

  config.system.activationScripts.installerDesktop = let
   # Comes from documentation.nix when xserver and nixos.enable are true.
   manualDesktopFile = "/run/current-system/sw/share/applications/nixos-manual.desktop";
   homeDir = "/home/${username}/";
   desktopDir = homeDir + "Desktop/";
  in ''
   mkdir -p ${desktopDir}
   chown ${username} ${homeDir} ${desktopDir}
   ln -sfT ${manualDesktopFile} ${desktopDir + "nixos-manual.desktop"}
   ln -sfT ${pkgs.gparted}/share/applications/gparted.desktop ${desktopDir + "gparted.desktop"}
   ln -sfT ${pkgs.pantheon.elementary-terminal}/share/applications/io.elementary.terminal.desktop ${desktopDir + "io.elementary.terminal.desktop"}
   ln -sfT ${pkgs.calamares-nixos}/share/applications/io.calamares.calamares.desktop ${desktopDir + "io.calamares.calamares.desktop"}
  '';

  config.isoImage.edition = lib.mkForce "${desktop}";
  config.system.stateVersion = lib.mkForce lib.trivial.release;
  config.services.xserver.displayManager.autoLogin.user = "${username}";
}
