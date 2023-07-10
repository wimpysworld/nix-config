{ config, desktop, lib, pkgs, username, ... }: {
  config.environment.systemPackages = with pkgs; [
    gparted
  ];
  config.systemd.tmpfiles.rules = [
    "d /home/${username}/Desktop 0755 ${username} users"
    "L+ /home/${username}/Desktop/gparted.desktop - - - - ${pkgs.gparted}/share/applications/gparted.desktop"
    "L+ /home/${username}/Desktop/io.elementary.terminal.desktop - - - - ${pkgs.pantheon.elementary-terminal}/share/applications/io.elementary.terminal.desktop"
    "L+ /home/${username}/Desktop/io.calamares.calamares.desktop - - - - ${pkgs.calamares-nixos}/share/applications/io.calamares.calamares.desktop"
  ];
  config.isoImage.edition = lib.mkForce "${desktop}";
  config.services.xserver.displayManager.autoLogin.user = "${username}";
  config.services.kmscon.autologinUser = lib.mkForce null;
}
