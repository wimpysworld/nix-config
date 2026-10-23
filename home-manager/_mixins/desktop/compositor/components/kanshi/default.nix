{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  inherit (import ../../../../../../lib/wayland-compositors.nix) compositors;
  wdisplays = import ./wdisplays.nix { inherit config pkgs; };
  kanshictl = "${config.services.kanshi.package}/bin/kanshictl";
  systemctl = config.systemd.user.systemctlPath;
in
lib.mkIf (host.is.linux && host.is.workstation && compositors ? ${toString host.desktop}) {
  # kanshi speaks wlr-output-management, so it applies display layouts under
  # any wlroots compositor. The Home Manager module binds the service to
  # wayland.systemd.target, the selected compositor's session target. The only
  # profiles are those that wdisplays saves. kanshi applies the first profile,
  # in file order, whose outputs match the connected displays exactly.
  services.kanshi = {
    enable = true;
    settings = [ { include = wdisplays.configFile; } ];
  };

  home.activation = {
    # kanshi fails to load a configuration whose include file is missing, so
    # the file exists before systemd starts kanshi. kanshi runs without
    # profiles while the file is empty.
    kanshiWdisplaysConfig = lib.hm.dag.entryBetween [ "reloadSystemd" ] [ "writeBoundary" ] ''
      configFile=${lib.escapeShellArg wdisplays.configFile}
      if [[ ! -e "$configFile" ]]; then
        run mkdir -p "$(dirname "$configFile")"
        run touch "$configFile"
      fi
    '';

    # A compositor configuration reload can change the display layout: Mango
    # re-enables a disabled output and Wayfire resets external outputs. kanshi
    # reapplies the matching profile. A stopped kanshi or a missing session
    # never fails activation.
    kanshiReload = lib.hm.dag.entryAfter [ "reloadSystemd" ] ''
      if ${systemctl} --user is-active --quiet kanshi.service 2>/dev/null; then
        waylandDisplay="''${WAYLAND_DISPLAY:-$(${systemctl} --user show-environment 2>/dev/null | ${pkgs.gnused}/bin/sed -n 's/^WAYLAND_DISPLAY=//p' || true)}"
        run env WAYLAND_DISPLAY="$waylandDisplay" ${kanshictl} reload || true
      fi
    '';
  };

  # Save layouts to the kanshi configuration without a toggle in wdisplays.
  dconf.settings."network/cycles/wdisplays".save-kanshi-config = true;
}
