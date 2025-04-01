{
  config,
  isInstall,
  lib,
  pkgs,
  username,
  ...
}:
let
  dbusService = if config.services.dbus.implementation == "broker"
    then "dbus-broker.service"
    else "dbus.service";
  mkHiddenWaylandSession = name: pkgs.writeTextDir "share/wayland-sessions/${name}.desktop" ''
    [Desktop Entry]
    Name="Hidden-${name}"
    NoDisplay=true
  '';
  # Create a Wayland session that starts Hyprland and cleans up after itself
  hyprShim = pkgs.symlinkJoin {
    name = "hyprshim";
    paths = [
      (pkgs.writeShellScriptBin "Hyprshim" ''
        # Ensure log directory exists
        LOG_DIR="$HOME/.local/log"
        LOG_FILE="$LOG_DIR/hyprland.log"
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
        # Run Hyprland and log output
        ${pkgs.expect}/bin/unbuffer /run/current-system/sw/bin/Hyprland $@ 2>&1 | ${pkgs.coreutils}/bin/tee -a "$LOG_FILE" &>/dev/null
        # Log the exit code here
        echo "[$(${pkgs.coreutils}/bin/date '+%Y-%m-%d %H:%M:%S')] Hyprland exited with code $?" | ${pkgs.coreutils}/bin/tee -a "$LOG_FILE"
        UNITS=(
          xdg-desktop-portal-hyprland.service
          xdg-desktop-portal-gtk.service
          xdg-desktop-portal.service
          waybar.service
          ${dbusService}
          hyprland-session.target
        )
        for UNIT in "''${UNITS[@]}"; do
          echo "[$(${pkgs.coreutils}/bin/date '+%Y-%m-%d %H:%M:%S')] Checking $UNIT" | ${pkgs.coreutils}/bin/tee -a "$LOG_FILE"
          if /run/current-system/sw/bin/systemctl --user --machine=${username}@.host list-unit-files "$UNIT" &>/dev/null; then
            if /run/current-system/sw/bin/systemctl --user --machine=${username}@.host is-active "$UNIT" &>/dev/null; then
              echo "[$(${pkgs.coreutils}/bin/date '+%Y-%m-%d %H:%M:%S')] Stopping $UNIT" | ${pkgs.coreutils}/bin/tee -a "$LOG_FILE"
              /run/current-system/sw/bin/systemctl --user --machine=${username}@.host stop "$UNIT"
            else
              echo "[$(${pkgs.coreutils}/bin/date '+%Y-%m-%d %H:%M:%S')] $UNIT is not running" | ${pkgs.coreutils}/bin/tee -a "$LOG_FILE"
            fi
          else
            echo "[$(${pkgs.coreutils}/bin/date '+%Y-%m-%d %H:%M:%S')] $UNIT not found" | ${pkgs.coreutils}/bin/tee -a "$LOG_FILE"
          fi
        done
      '')
      (pkgs.writeTextFile {
        name = "hyprshim-desktop";
        destination = "/share/wayland-sessions/Hyprshim.desktop";
        text = ''
          [Desktop Entry]
          Name=Hyprland
          Comment=An intelligent dynamic tiling Wayland compositor
          Exec=Hyprshim
          Type=Application
          DesktopNames=Hyprland
          Keywords=tiling;wayland;compositor;
        '';
      })
    ];
    # Add passthru metadata to specify session names
    passthru.providedSessions = [ "Hyprshim" ];
  };
in
{
  imports = [ ../greeters/greetd.nix ];
  environment = {
    # Enable HEIC image previews in Nautilus
    pathsToLink = [ "/share" "share/thumbnailers" ];
    sessionVariables = {
      # Make sure the cursor size is the same in all environments
      HYPRCURSOR_SIZE = 32;
      HYPRCURSOR_THEME = "catppuccin-mocha-blue-cursors";
      NIXOS_OZONE_WL = 1;
      QT_WAYLAND_DISABLE_WINDOWDECORATION = 1;
      # The the desktop sessions provided by the Hyprland package
      XDG_DATA_DIRS = [
        "${mkHiddenWaylandSession "hyprland"}/share"
        "${mkHiddenWaylandSession "hyprland-systemd"}/share"
      ];
    };
    systemPackages =
      with pkgs;
      lib.optionals isInstall [
        catppuccin-cursors
        gnome-font-viewer
        hyprShim
        # Enable HEIC image previews in Nautilus
        libheif
        libheif.out
        nautilus
        polkit_gnome
        resources
        wdisplays
        wlr-randr
        wl-clipboard
        wtype
        zenity
      ];
  };

  programs = {
    dconf.profiles.user.databases = [
      {
        settings = with lib.gvariant; {
          "org/gnome/desktop/interface" = {
            clock-format = "24h";
            color-scheme = "prefer-dark";
            cursor-size = mkInt32 32;
            cursor-theme = "catppuccin-mocha-blue-cursors";
            document-font-name = "Work Sans 12";
            font-name = "Work Sans 12";
            gtk-theme = "catppuccin-mocha-blue-standard";
            gtk-enable-primary-paste = true;
            icon-theme = "Papirus-Dark";
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
    file-roller.enable = isInstall;
    gnome-disks.enable = isInstall;
    hyprland = {
      enable = true;
      systemd.setPath.enable = true;
    };
    iio-hyprland = {
      enable = true;
    };
    nautilus-open-any-terminal = {
      enable = true;
      terminal = "foot";
    };
    seahorse.enable = isInstall;
    udevil.enable = true;
  };
  security = {
    pam.services.hyprlock = { };
    polkit = {
      enable = true;
    };
  };

  services = {
    dbus = {
      implementation = "broker";
      packages = with pkgs; [ gcr ];
    };
    devmon.enable = true;
    displayManager = {
      sessionPackages = [ hyprShim ];
    };
    gnome = {
      gnome-keyring.enable = isInstall;
      sushi.enable = isInstall;
    };
    gvfs.enable = true;
    udisks2.enable = true;
  };
}
