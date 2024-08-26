{
  hostname,
  lib,
  pkgs,
  ...
}:
let
  monitors = (import ./monitors.nix { }).${hostname};
  appLauncher = "fuzzel";         # fuzzel or walker
  notificationDaemon = "swaync";  # mako or swaync
  onScreenDisplay = "avizo";      # avizo
  statusBar = "waybar";           # gBar or waybar
in
{
  # Hyprland is a Wayland-based tile window manager
  # It requires additional components to create a full desktop shell
  # I've broken these components into separate files for organization and
  # so I can enable/disable them as I experiment with different setups
  imports = [
    ./${appLauncher}.nix         # app launcher, emoji picker and clipboard manager
    ./${notificationDaemon}      # notification daemon
    ./${statusBar}.nix           # status bar
    ./${onScreenDisplay}.nix     # on-screen display for audio and backlight
    ./grimblast.nix              # screenshot grabber and editor
    ./hyprlock.nix               # screen locker
    ./hyprpaper.nix              # wallpaper setter
    ./wlogout                    # session menu
  ];
  services = {
    gpg-agent.pinentryPackage = lib.mkForce pkgs.pinentry-gnome3;
    udiskie = {
      enable = true;
      automount = false;
      tray = "auto";
      notify = true;
    };
  };

  systemd.user.services.polkit-gnome-authentication-agent-1 = {
    Unit.Description = "polkit-gnome-authentication-agent-1";
    Install.WantedBy = [ "hyprland-session.target" ];
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
      Restart = "on-failure";
      RestartSec = 1;
      TimeoutStopSec = 10;
    };
  };

  wayland.windowManager.hyprland = {
    enable = true;
    catppuccin.enable = true;
    settings = {
      inherit (monitors) monitor workspace;
      "$mod" = "SUPER";
      # Work when input inhibitor (l) is active.
      bindl = [
        ", XF86AudioPlay, exec, ${lib.getExe pkgs.playerctl} play-pause"
        ", XF86AudioPrev, exec, ${lib.getExe pkgs.playerctl} previous"
        ", XF86AudioNext, exec, ${lib.getExe pkgs.playerctl} next"
      ];
      bind = [
        # Process management
        "ALT, Q, killactive"
        # Launch applications
        "$mod, E, exec, nautilus --new-window"
        "$mod, T, exec, alacritty"
        # Move focus
        "ALT, Tab, cyclenext"
        "ALT, Tab, bringactivetotop"
        "ALT SHIFT, Tab, cyclenext, prev"
        "ALT SHIFT, Tab, bringactivetotop"
        # Move focus with $mod + arrow keys
        "$mod, left, movefocus, l"
        "$mod, right, movefocus, r"
        "$mod, up, movefocus, u"
        "$mod, down, movefocus, d"
        # Switch workspace
        "CTRL ALT, left, workspace, e-1"
        "CTRL ALT, right, workspace, e+1"
        ]
        ++ (
        # workspaces
        # binds ctrl + alt + {1..8} to switch to workspace {1..8}
        # binds $mod + alt + {1..8} to move window to workspace {1..8}
        builtins.concatLists (builtins.genList (
            x: let
              ws = let
                c = (x + 1) / 9;
              in
                builtins.toString (x + 1 - (c * 9));
            in [
              "CTRL ALT, ${ws}, workspace, ${toString (x + 1)}"
              "$mod ALT,  ${ws}, movetoworkspace, ${toString (x + 1)}"
            ]
          )
          9)
      );
      # https://wiki.hyprland.org/Configuring/Variables/#animations
      # https://wiki.hyprland.org/Configuring/Animations/
      animation = [
        "windows, 1, 6, wind, slide"
        "windowsIn, 1, 6, winIn, slide"
        "windowsOut, 1, 5, winOut, slide"
        "windowsMove, 1, 5, wind, slide"
        "border, 1, 1, liner"
        "borderangle, 1, 30, liner, loop"
        "fade, 1, 10, default"
        "workspaces, 1, 5, wind"
      ];
      bezier = [
        "wind, 0.05, 0.9, 0.1, 1.05"
        "winIn, 0.1, 1.1, 0.1, 1.1"
        "winOut, 0.3, -0.3, 0, 1"
        "liner, 1, 1, 1, 1"
      ];
      decoration = {
        rounding = 8;
        # Change transparency of focused and unfocused windows
        active_opacity = 1.0;
        inactive_opacity = 1.0;
        drop_shadow = true;
        shadow_range = 4;
        shadow_render_power = 3;
        "col.shadow" = "rgba(1a1a1aee)";
      };
      dwindle = {
        preserve_split = true;
        force_split = 2;
      };
      exec = [
        "sleep 5 && trayscale --gapplication-service --hide-window"
      ];
      general = {
        gaps_in = 5;
        gaps_out = 5;
        border_size = 2;
        # https://wiki.hyprland.org/Configuring/Variables/#variable-types for info about colors
        #"col.active_border" = "rgb(8aadf4) rgb(24273A) rgb(24273A) rgb(8aadf4) 45deg";
        "col.inactive_border" = "rgb(24273A) rgb(24273A) rgb(24273A) rgb(27273A) 45deg";
        "col.active_border" = "rgba(89b4faee)";
        #"col.inactive_border" = "rgba(11111baa)";
      };
      gestures = {
        workspace_swipe = true;
        workspace_swipe_forever = true;
        workspace_swipe_invert = false;
      };
      group = {
        groupbar = {
          font_family = "Work Sans";
          font_size = 12;
          gradients = true;
        };
      };
      input = {
        kb_layout = "gb";
        follow_mouse = 2;
        repeat_rate = 50;
        repeat_delay = 300;
      };
      misc = {
        background_color = "rgb(69, 71, 90)";
        disable_hyprland_logo = true;
        disable_splash_rendering = true;
        animate_manual_resizes = true;
      };
      windowrulev2 = [
        # only allow shadows for floating windows
        "noshadow, floating:0"

        # idle inhibit while watching videos
        "idleinhibit focus, class:^(mpv|.+exe)$"
        "idleinhibit fullscreen, class:.*"

        # make Firefox PiP window floating and sticky
        "float, title:^(Picture-in-Picture)$"
        "pin, title:^(Picture-in-Picture)$"

        "float, class:^(1Password)$"
        "stayfocused,title:^(Quick Access — 1Password)$"
        "dimaround,title:^(Quick Access — 1Password)$"
        "noanim,title:^(Quick Access — 1Password)$"

        # make pop-up file dialogs floating, centred, and pinned
        "float, title:(Open|Progress|Save File)"
        "center, title:(Open|Progress|Save File)"
        "pin, title:(Open|Progress|Save File)"
        "float, class:^(code)$"
        "center, class:^(code)$"
        "pin, class:^(code)$"

        # assign windows to workspaces
        #"workspace 1 silent, class:[Bb]rave"
        #"workspace 2 silent, class:[Ww]avebox"
        #"workspace 4 silent, class:code-url-handler"

        # throw sharing indicators away
        "workspace special silent, title:^(Firefox — Sharing Indicator)$"
        "workspace special silent, title:^(.*is sharing (your screen|a window)\.)$"
      ];
      xwayland = {
        force_zero_scaling = true;
      };
    };
    systemd.enableXdgAutostart = true;
    xwayland.enable = true;
  };
}
