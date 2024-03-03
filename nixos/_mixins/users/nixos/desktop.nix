{ config, desktop, hostname, lib, pkgs, username, ... }:
let
  isInstall = if (builtins.substring 0 4 hostname != "iso-") then true else false;
  isISO = !isInstall;
in
{
  config.environment = {
    etc = lib.mkIf (isISO) {
      "firefox.dockitem".source = pkgs.writeText "firefox.dockitem" ''
        [PlankDockItemPreferences]
        Launcher=file:///run/current-system/sw/share/applications/firefox.desktop
      '';
      "firefox.dockitem".target = "/plank/firefox.dockitem";

      "io.elementary.files.dockitem".source = pkgs.writeText "io.elementary.files.dockitem" ''
        [PlankDockItemPreferences]
        Launcher=file:///run/current-system/sw/share/applications/io.elementary.files.desktop
      '';
      "io.elementary.files.dockitem".target = "/plank/io.elementary.files.dockitem";

      "io.elementary.terminal.dockitem".source = pkgs.writeText "io.elementary.terminal.dockitem" ''
        [PlankDockItemPreferences]
        Launcher=file:///run/current-system/sw/share/applications/io.elementary.terminal.desktop
      '';
      "io.elementary.terminal.dockitem".target = "/plank/io.elementary.terminal.dockitem";

      "gparted.dockitem".source = pkgs.writeText "gparted.dockitem" ''
        [PlankDockItemPreferences]
        Launcher=file:///run/current-system/sw/share/applications/gparted.desktop
      '';
      "gparted.dockitem".target = "/plank/gparted.dockitem";
    };
    systemPackages = lib.optionals (isISO) [
      pkgs.gparted
    ];
  };

  config.isoImage = lib.mkIf (isISO) {
    edition = lib.mkForce "${desktop}";
  };

  config.programs = {
    dconf.profiles.user.databases = [{
      settings = with lib.gvariant; lib.mkIf (isISO) {
        "net/launchpad/plank/docks/dock1" = {
          dock-items = [ "firefox.dockitem" "io.elementary.files.dockitem" "io.elementary.terminal.dockitem" "gparted.dockitem" ];
        };

        "org/gnome/shell" = {
          disabled-extensions = mkEmptyArray type.string;
          favorite-apps = [ "firefox.desktop" "org.gnome.Nautilus.desktop" "org.gnome.Console.desktop" "io.calamares.calamares.desktop" "gparted.desktop" ];
          welcome-dialog-last-shown-version = "9999999999";
        };
      };
    }];
  };

  config.services.xserver = {
    displayManager.autoLogin = lib.mkIf (isISO) {
      user = "${username}";
    };
  };

  # Create desktop shortcuts and dock items for the live media
  config.systemd.tmpfiles = lib.mkIf (isISO) {
    rules = [
      "d /home/${username}/Desktop 0755 ${username} users"
      "d /home/${username}/.config 0755 ${username} users"
      "d /home/${username}/.config/plank 0755 ${username} users"
      "d /home/${username}/.config/plank/dock1 0755 ${username} users"
      "d /home/${username}/.config/plank/dock1/launchers 0755 ${username} users"
      "L+ /home/${username}/.config/plank/dock1/launchers/firefox.dockitem - - - - /etc/plank/firefox.dockitem"
      "L+ /home/${username}/.config/plank/dock1/launchers/io.elementary.files.dockitem - - - - /etc/plank/io.elementary.files.dockitem"
      "L+ /home/${username}/.config/plank/dock1/launchers/io.elementary.terminal.dockitem - - - - /etc/plank/io.elementary.terminal.dockitem"
      "L+ /home/${username}/.config/plank/dock1/launchers/gparted.dockitem - - - - /etc/plank/gparted.dockitem"
      "L+ /home/${username}/Desktop/firefox.desktop - - - - ${pkgs.firefox}/share/applications/firefox.desktop"
      "L+ /home/${username}/Desktop/io.calamares.calamares.desktop - - - - ${pkgs.calamares-nixos}/share/applications/io.calamares.calamares.desktop"
      "L+ /home/${username}/Desktop/gparted.desktop - - - - ${pkgs.gparted}/share/applications/gparted.desktop"
    ] ++ lib.optionals (isISO && desktop == "mate") [
      "L+ /home/${username}/Desktop/caja.desktop - - - - ${pkgs.mate.caja}/share/applications/caja.desktop"
      "L+ /home/${username}/Desktop/mate-terminal.desktop - - - - ${pkgs.mate.mate-terminal}/share/applications/mate-terminal.desktop"
    ];
  };
}
