{
  default = "mango";

  compositors = {
    mango = {
      launcher = {
        name = "Mango";
        comment = "A dwl-based tiling Wayland compositor with scenefx effects";
        desktopNames = "mango";
        command = "mango";
        prefixArgs = [ ];
        logName = "mango";
        nativeSessions = [ "mango" ];
      };
      # Mango ships mango-session.target and starts it itself, so the
      # repository only joins that start and treats its failure as best-effort.
      sessionTarget = "mango-session.target";
      compositorStartsSessionTarget = true;
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
        # SwayNC gets no blur behind it, so its surfaces need more opacity.
        opaqueLayers = true;
      };
      # The Mango Home Manager module defines the custom/tagN modules, because
      # their commands need store paths. Waybar's ext/workspaces cannot sync
      # Mango tags across monitors.
      waybar = {
        workspaceModule = "group/workspaces";
        workspaceSettings = {
          orientation = "inherit";
          modules = builtins.genList (i: "custom/tag${toString (i + 1)}") 8;
        };
        tagIcons = {
          "1" = "󰎤";
          "2" = "󰎧";
          "3" = "󰎪";
          "4" = "󰎭";
          "5" = "󰎱";
          "6" = "󰎳";
          "7" = "󰎶";
          "8" = "󰎹";
        };
      };
    };

    wayfire = {
      launcher = {
        name = "Wayfire";
        comment = "A modular and extensible Wayland compositor";
        desktopNames = "Wayfire";
        command = "wayfire";
        prefixArgs = [ ];
        logName = "wayfire";
        nativeSessions = [ "wayfire" ];
      };
      sessionTarget = "wayfire-session.target";
      compositorStartsSessionTarget = false;
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
        opaqueLayers = false;
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
