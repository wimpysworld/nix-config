{
  hostname,
  lib,
  pkgs,
  ...
}:
let
  isLaptop = hostname != "vader" && hostname != "phasma" && hostname != "revan";
  monitors = (import ./monitors.nix { }).${hostname};
in
{
  # Hyprland is a Wayland compositor and dynamic tiling window manager
  # Additional applications are required to create a full desktop shell
  imports = [
    ./avizo        # on-screen display for audio and backlight
    ./fuzzel       # app launcher, emoji picker and clipboard manager
    ./grimblast    # screenshot grabber and annotator
    ./hyprlock     # screen locker
    ./hyprpaper    # wallpaper setter
    ./swaync       # notification center
    ./waybar       # status bar
    ./wlogout      # session menu
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
      inherit (monitors) monitor;
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
      animations = {
        enabled = true;
        first_launch_animation = false;
      };
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
      master = {
        orientation = if hostname == "vader" then "top" else "left";
      };
      dwindle = {
        preserve_split = true;
        force_split = 2;
      };
      exec-once = [
        #"sleep 1 && hyprctl dispatch exec [workspace 1 silent] brave"
        #"sleep 2 && hyprctl dispatch exec [workspace 2 silent] wavebox"
        #"sleep 2 && hyprctl dispatch exec [workspace 2 silent] discord"
        #"sleep 3 && hyprctl dispatch exec [workspace 3 silent] telegram-desktop"
        #"sleep 3 && hyprctl dispatch exec [workspace 3 silent] fractal"
        #"sleep 4 && hyprctl dispatch exec [workspace 4 silent] code"
        #"sleep 4 && hyprctl dispatch exec [workspace 4 silent] gitkraken"
        #"sleep 5 && hyprctl dispatch exec [workspace 5 silent] alacritty"
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
        # Set to true enable resizing windows by clicking and dragging on borders and gaps
        resize_on_border = true;
        extend_border_grab_area = 10;
        layout = "master";
      };
      gestures = {
        workspace_swipe = true;
        workspace_swipe_forever = false;
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
        repeat_rate = 30;
        repeat_delay = 300;
        touchpad = {
          clickfinger_behavior = true;
          middle_button_emulation = true;
          natural_scroll = true;
          tap-to-click = true;
        };
      };
      misc = {
        animate_manual_resizes = true;
        background_color = "rgb(30, 30, 46)";
        disable_hyprland_logo = true;
        disable_splash_rendering = true;
        mouse_move_enables_dpms = true;
        key_press_enables_dpms = true;
      };
      windowrulev2 = [
        # only allow shadows for floating windows
        "noshadow, floating:0"

        # make pop-up file dialogs floating, centred, and pinned
        "float, title:(Open|Progress|Save File)"
        "center, title:(Open|Progress|Save File)"
        "pin, title:(Open|Progress|Save File)"
        "float, class:^(code)$"
        "center, class:^(code)$"
        "pin, class:^(code)$"
      ];
      # Simulate static workspaces
      workspace = [
        "1, name:Web, persistent:true, monitor:*, default:true"
        "2, name:Work, persistent:true, monitor:*"
        "3, name:Chat, persistent:true, monitor:*"
        "4, name:Code, persistent:true, monitor:*"
        "5, name:Term, persistent:true, monitor:*"
        "6, name:Cast, persistent:true, monitor:*"
        "7, name:Virt, persistent:true, monitor:*"
        "8, name:Fun, persistent:true, monitor:*"
      ];
      xwayland = {
        force_zero_scaling = true;
      };
    };
    systemd = {
      enableXdgAutostart = true;
      variables = [ "--all" ];
    };
    xwayland.enable = true;
  };
}
