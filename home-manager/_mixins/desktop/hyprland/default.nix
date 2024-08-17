{
  hostname,
  lib,
  pkgs,
  ...
}:
let
  monitors = (import ./monitors.nix { }).${hostname};
  appLauncher = "fuzzel";       # fuzzel or walker
  notificationDaemon = "mako";  # mako or swaync (TBD)
  onScreenDisplay = "avizo";    # avizo
  statusBar = "waybar";         # gBar or waybar
in
{
  # Hyprland is a Wayland-based tile window manager
  # It requires additional components to create a full desktop shell
  # I've broken these components into separate files for organization and
  # so I can enable/disable them as I experiment with different setups
  imports = [
    ./${appLauncher}.nix         # app launcher, emoji picker and clipboard manager
    ./${notificationDaemon}.nix  # notification daemon
    ./${statusBar}.nix           # status bar
    ./${onScreenDisplay}.nix     # on-screen display for audio and backlight
    ./grimblast.nix              # screenshot grabber and editor
    ./hyprlock.nix               # screen locker
    ./hyprpaper.nix              # wallpaper setter
  ];
  services = {
    gpg-agent.pinentryPackage = lib.mkForce pkgs.pinentry-gnome3;
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
        "$mod, E, exec, nautilus --new-window"
        "$mod, T, exec, alacritty"
        "ALT, Q, killactive"
        "ALT, Tab, cyclenext"
        "ALT, Tab, bringactivetotop"
        "ALT SHIFT, Tab, cyclenext, prev"
        "ALT SHIFT, Tab, bringactivetotop"
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
      animation = [
        "border, 1, 2, default"
        "fade, 1, 4, default"
        "windows, 1, 3, default, popin 80%"
        "workspaces, 1, 2, default, slide"
      ];
      decoration = {
        rounding = 8;
        drop_shadow = true;
        shadow_ignore_window = true;
        shadow_offset = "0 5";
        shadow_range = 16;
        shadow_render_power = 3;
        "col.shadow" = "rgba(00000099)";
      };
      dwindle = {
        preserve_split = true;
        force_split = 2;
      };
      exec = [
        "sleep 5 && trayscale --gapplication-service --hide-window"
      ];
      general = {
        gaps_in = 4;
        gaps_out = 8;
        border_size = 1;
        "col.active_border" = "rgba(89b4faee)";
        "col.inactive_border" = "rgba(11111baa)";
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
        "workspace 1 silent, class:[Bb]rave"
        "workspace 2 silent, class:[Ww]avebox"
        "workspace 4 silent, class:code-url-handler"

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
