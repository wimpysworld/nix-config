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
      portal = {
        backend = "hyprland";
        packageAttr = "xdg-desktop-portal-hyprland";
        service = "xdg-desktop-portal-hyprland";
      };
      capabilities = {
        clientSideDecorations = false;
        picker = true;
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
      portal = {
        backend = "wlr";
        packageAttr = "xdg-desktop-portal-wlr";
        service = "xdg-desktop-portal-wlr";
      };
      capabilities = {
        clientSideDecorations = true;
        picker = false;
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
          on-click = "activate";
          sort-by-number = true;
        };
      };
    };
  };
}
