{
  catppuccinPalette,
  config,
  isInstall,
  lib,
  pkgs,
  ...
}:
let
  mkHiddenWaylandSession =
    name:
    pkgs.writeTextDir "share/wayland-sessions/${name}.desktop" ''
      [Desktop Entry]
      Name="Hidden-${name}"
      NoDisplay=true
    '';
  # Create a Wayland session that starts Wayfire and cleans up after itself
  wayfireShim = pkgs.symlinkJoin {
    name = "wayfireShim";
    paths = [
      (pkgs.writeShellScriptBin "WayfireShim" ''
        # Ensure log directory exists
        LOG_DIR="$HOME/.local/log"
        LOG_FILE="$LOG_DIR/wayfire.log"
        mkdir -p "$LOG_DIR"
        # Rotate logs before starting new session
        if [ -f "$LOG_FILE" ]; then
          # Remove oldest log (10)
          [ -f "$LOG_FILE.10" ] && rm "$LOG_FILE.10"
          # Rotate existing logs
          for i in $(seq 9 -1 1); do
            [ -f "$LOG_FILE.$i" ] && mv "$LOG_FILE.$i" "$LOG_FILE.$((i+1))"
          done
          # Move current log to .1
          mv "$LOG_FILE" "$LOG_FILE.1"
        fi
        # Run Wayfire and log output
        ${pkgs.expect}/bin/unbuffer /run/current-system/sw/bin/wayfire $@ 2>&1 | ${pkgs.coreutils}/bin/tee -a "$LOG_FILE" &>/dev/null
        # Log the exit code here
        echo "[$(${pkgs.coreutils}/bin/date '+%Y-%m-%d %H:%M:%S')] Wayfire exited with code $?" | ${pkgs.coreutils}/bin/tee -a "$LOG_FILE"
      '')
      (pkgs.writeTextFile {
        name = "wayfireShim-desktop";
        destination = "/share/wayland-sessions/WayfireShim.desktop";
        text = ''
          [Desktop Entry]
          Name=Wayfire
          Comment=A modular and extensible wayland compositor
          Exec=WayfireShim
          Type=Application
          DesktopNames=Wayfire
          Keywords=tiling;wayland;compositor;
        '';
      })
    ];
    # Add passthru metadata to specify session names
    passthru.providedSessions = [ "WayfireShim" ];
  };
in
{
  imports = [ ../greeters/greetd.nix ];
  config = lib.mkIf (config.noughty.host.desktop == "wayfire") {
    environment = {
      sessionVariables = {
        # Make sure the cursor size is the same in all environments
        XCURSOR_SIZE = 32;
        XCURSOR_THEME = "catppuccin-${catppuccinPalette.flavor}-${catppuccinPalette.accent}-cursors";
        NIXOS_OZONE_WL = 1;
        # Hide the default wayfire session provided by the Wayfire package
        XDG_DATA_DIRS = [
          "${mkHiddenWaylandSession "wayfire"}/share"
        ];
      };
      systemPackages =
        with pkgs;
        lib.optionals isInstall [
          wayfireShim
          wayfire
        ];
    };

    programs = {
      dconf.profiles.user.databases = [
        {
          settings = with lib.gvariant; {
            "org/gnome/desktop/interface" = {
              clock-format = "24h";
              color-scheme = "${catppuccinPalette.preferShade}";
              cursor-size = mkInt32 32;
              cursor-theme = "catppuccin-${catppuccinPalette.flavor}-${catppuccinPalette.accent}-cursors";
              document-font-name = "Work Sans 12";
              font-name = "Work Sans 12";
              gtk-theme = "catppuccin-${catppuccinPalette.flavor}-${catppuccinPalette.accent}-standard";
              gtk-enable-primary-paste = true;
              icon-theme = "Papirus${catppuccinPalette.themeShade}";
              monospace-font-name = "FiraCode Nerd Font Mono Medium 13";
              text-scaling-factor = mkDouble 1.0;
            };

            "org/gnome/desktop/sound" = {
              theme-name = "freedesktop";
            };

            "org/gtk/gtk4/Settings/FileChooser" = {
              clock-format = "24h";
            };

            "org/gtk/Settings/FileChooser" = {
              clock-format = "24h";
            };
          };
        }
      ];
      wayfire = {
        enable = true;
      };
    };

    services = {
      displayManager = {
        sessionPackages = [ wayfireShim ];
      };
    };
  };
}
