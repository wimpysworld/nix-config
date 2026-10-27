{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  compositor =
    if host.is.linux && host.is.workstation then
      lib.attrByPath [ host.desktop ] null (import ../../../../lib/wayland-compositors.nix).compositors
    else
      null;
in
{
  imports = [
    ./components/battery-refresh
    ./components/capture
    ./components/fuzzel
    ./components/kanshi
    ./components/picker
    ./components/rofi
    ./components/swaync
    ./components/swayosd
    ./components/veila
    ./components/waybar
    ./components/wleave
    ./components/wpaperd
    ./mango
    ./wayfire
  ];

  # The selected compositor's module defines the Waybar modules that its
  # contract workspace module refers to, for example the members of a group.
  # The shared Waybar component adds them to the bar.
  options.compositor.waybar.modules = lib.mkOption {
    type = lib.types.attrsOf (pkgs.formats.json { }).type;
    default = { };
    internal = true;
    description = "Waybar module definitions from the selected compositor's module.";
  };

  options.compositor.keybindingHelp.entries = lib.mkOption {
    type = lib.types.listOf (
      lib.types.submodule {
        options = {
          description = lib.mkOption { type = lib.types.str; };
          keys = lib.mkOption { type = lib.types.str; };
          category = lib.mkOption { type = lib.types.str; };
          keywords = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
          };
        };
      }
    );
    default = [ ];
    internal = true;
    description = "Read-only help for the selected compositor's configured keyboard shortcuts.";
  };

  config = lib.mkIf (compositor != null) {
    home.activation.removeObsoleteGraphicalSessionDependencies =
      lib.mkIf
        (
          config.wayland.systemd.target != "graphical-session.target"
          && lib.hasPrefix "${config.home.homeDirectory}/" config.xdg.configHome
        )
        (
          lib.hm.dag.entryBetween [ "linkGeneration" ] [ "writeBoundary" ] ''
            (
              configHome=${lib.escapeShellArg config.xdg.configHome}
              relativeConfigHome=${lib.escapeShellArg (lib.removePrefix "${config.home.homeDirectory}/" config.xdg.configHome)}
              for service in wpaperd.service avizo.service kanshi.service reframe-session.service swaync.service veilad.service veila-idle.service; do
                relativePath="$relativeConfigHome/systemd/user/graphical-session.target.wants/$service"
                obsoleteLink="$configHome/systemd/user/graphical-session.target.wants/$service"
                # A collected generation can leave a dependency outside the old generation's file list.
                if [[ ! -L "$configHome" && ! -L "$configHome/systemd" \
                    && ! -L "$configHome/systemd/user" \
                    && ! -L "$configHome/systemd/user/graphical-session.target.wants" \
                    && -L "$obsoleteLink" && ! -e "$obsoleteLink" \
                    && ! -e "$newGenPath/home-files/$relativePath" \
                    && ! -L "$newGenPath/home-files/$relativePath" ]]; then
                  destination="$(${pkgs.coreutils}/bin/readlink -- "$obsoleteLink")"
                  if [[ "$destination" =~ ^${lib.escapeShellArg builtins.storeDir}/[0-9abcdfghijklmnpqrsvwxyz]{32}-home-manager-files/"$relativePath"$ ]]; then
                    run ${pkgs.coreutils}/bin/rm -- "$obsoleteLink"
                  fi
                fi
              done
            )
          ''
        );

    home.packages = [ (import ./components/kanshi/wdisplays.nix { inherit config pkgs; }).package ];
    wayland.systemd.target = compositor.sessionTarget;
  };
}
