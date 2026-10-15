{
  default = "hyprland";

  compositors = {
    hyprland = {
      launcher = {
        name = "Hyprland";
        comment = "An intelligent dynamic tiling Wayland compositor";
        desktopNames = "Hyprland";
        command = "/run/current-system/sw/bin/start-hyprland";
        prefixArgs = [ "--" ];
        logName = "hyprland";
        nativeSessionsPath = [
          "programs"
          "hyprland"
          "package"
          "providedSessions"
        ];
      };
      sessionTarget = "hyprland-session.target";
      startupEnvironment = [
        "DISPLAY"
        "WAYLAND_DISPLAY"
        "XDG_SESSION_TYPE"
        "XDG_CURRENT_DESKTOP"
        "NIXOS_OZONE_WL"
        "XCURSOR_THEME"
        "XCURSOR_SIZE"
        "HYPRLAND_INSTANCE_SIGNATURE"
      ];
      ephemeralEnvironment = [
        "DISPLAY"
        "HYPRLAND_INSTANCE_SIGNATURE"
        "WAYLAND_DISPLAY"
        "XDG_SESSION_TYPE"
        "XDG_CURRENT_DESKTOP"
      ];
      portal = {
        backend = "hyprland";
        packageAttr = "xdg-desktop-portal-hyprland";
        service = "xdg-desktop-portal-hyprland";
      };
      capabilities = {
        clientSideDecorations = false;
        picker = true;
        blurredNotifications = true;
      };
      waybar = {
        workspaceModule = "hyprland/workspaces";
        workspaceSettings = {
          active-only = false;
          all-outputs = true;
          format = "<big>{icon}</big>";
          format-icons = {
            "1" = "󰎤";
            "2" = "󰎧";
            "3" = "󰎪";
            "4" = "󰎭";
            "5" = "󰎱";
            "6" = "󰎳";
            "7" = "󰎶";
            "8" = "󰎹";
            "9" = "󰎼";
            "10" = "󰎡";
            default = "󱢍";
          };
          on-click = "activate";
          sort-by-number = true;
        };
      };
    };

    mango = {
      launcher = {
        name = "MangoWM";
        comment = "A dwl-based tiling Wayland compositor with scenefx effects";
        desktopNames = "mango";
        command = "/run/current-system/sw/bin/mango";
        prefixArgs = [ ];
        logName = "mango";
        nativeSessionsPath = [
          "programs"
          "mangowc"
          "package"
          "providedSessions"
        ];
      };
      sessionTarget = "mangowm-session.target";
      startupEnvironment = [
        "DISPLAY"
        "WAYLAND_DISPLAY"
        "XDG_SESSION_TYPE"
        "XDG_CURRENT_DESKTOP"
        "NIXOS_OZONE_WL"
        "XCURSOR_THEME"
        "XCURSOR_SIZE"
        "MANGO_INSTANCE_SIGNATURE"
      ];
      ephemeralEnvironment = [
        "DISPLAY"
        "MANGO_INSTANCE_SIGNATURE"
        "WAYLAND_DISPLAY"
        "XDG_SESSION_TYPE"
        "XDG_CURRENT_DESKTOP"
      ];
      portal = {
        backend = "wlr";
        packageAttr = "xdg-desktop-portal-wlr";
        service = "xdg-desktop-portal-wlr";
      };
      capabilities = {
        clientSideDecorations = false;
        picker = true;
        # SwayNC gets no blur, so its surfaces need more opacity.
        blurredNotifications = false;
      };
      waybar = {
        workspaceModule = "ext/workspaces";
        workspaceSettings = {
          active-only = false;
          all-outputs = false;
          format = "<big>{icon}</big>";
          format-icons = {
            "1" = "󰎤";
            "2" = "󰎧";
            "3" = "󰎪";
            "4" = "󰎭";
            "5" = "󰎱";
            "6" = "󰎳";
            "7" = "󰎶";
            "8" = "󰎹";
            default = "󱢍";
          };
          ignore-hidden = true;
          on-click = "activate";
          sort-by-number = true;
        };
      };
    };

    wayfire = {
      launcher = {
        name = "Wayfire";
        comment = "A modular and extensible Wayland compositor";
        desktopNames = "Wayfire";
        command = "/run/current-system/sw/bin/wayfire";
        prefixArgs = [ ];
        logName = "wayfire";
        nativeSessionsPath = [
          "programs"
          "wayfire"
          "package"
          "providedSessions"
        ];
      };
      sessionTarget = "wayfire-session.target";
      startupEnvironment = [
        "DISPLAY"
        "WAYLAND_DISPLAY"
        "XDG_SESSION_TYPE"
        "XDG_CURRENT_DESKTOP"
        "NIXOS_OZONE_WL"
        "XCURSOR_THEME"
        "XCURSOR_SIZE"
        "WAYFIRE_SOCKET"
      ];
      ephemeralEnvironment = [
        "DISPLAY"
        "WAYFIRE_SOCKET"
        "WAYLAND_DISPLAY"
        "XDG_SESSION_TYPE"
        "XDG_CURRENT_DESKTOP"
      ];
      portal = {
        backend = "wlr";
        packageAttr = "xdg-desktop-portal-wlr";
        service = "xdg-desktop-portal-wlr";
      };
      capabilities = {
        clientSideDecorations = true;
        picker = true;
        blurredNotifications = true;
      };
      waybar = {
        workspaceModule = "wayfire/workspaces";
        workspaceSettings = {
          format = "<big>{icon}</big>";
          format-icons = {
            "1" = "󰎤";
            "2" = "󰎧";
            "3" = "󰎪";
            "4" = "󰎭";
            "5" = "󰎱";
            "6" = "󰎳";
            "7" = "󰎶";
            "8" = "󰎹";
            "9" = "󰎼";
            "10" = "󰎡";
            default = "󱢍";
          };
        };
      };
    };
  };
}
