{ config, desktop, lib, pkgs, username, ... }: {
  config.system.activationScripts.installerDesktop = let
   homeDir = "/home/${username}/";
   desktopDir = homeDir + "Desktop/";
  in ''
   mkdir -p ${desktopDir}
   chown ${username} ${homeDir} ${desktopDir}
   ln -sfT ${pkgs.gparted}/share/applications/gparted.desktop ${desktopDir + "gparted.desktop"}
   ln -sfT ${pkgs.pantheon.elementary-terminal}/share/applications/io.elementary.terminal.desktop ${desktopDir + "io.elementary.terminal.desktop"}
   ln -sfT ${pkgs.calamares-nixos}/share/applications/io.calamares.calamares.desktop ${desktopDir + "io.calamares.calamares.desktop"}
  '';

  config.isoImage.edition = lib.mkForce "${desktop}";
  config.services.xserver.displayManager.autoLogin.user = "${username}";
  config.services.kmscon.autologinUser = lib.mkForce null;
}
