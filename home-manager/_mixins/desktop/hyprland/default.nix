{
  config,
  hostname,
  lib,
  pkgs,
  ...
}:
let
  monitors = (import ./monitors.nix { }).${hostname};
  portalProdder = pkgs.writeShellApplication {
    name = "portal-prodder";
    runtimeInputs = with pkgs; [ procps ];
    # Dirty hack to make sure the portal services are started correctly so that
    # screen capture/sharing works in OBS Studio and other applications
    # TODO: Try Coercing the units directly to enforce the "After" dependency
    text = ''
      set +e  # Disable errexit
      echo "Stop the desktop portal services..."
      pgrep --list-full xdg-desktop
      echo
      systemctl --user stop xdg-desktop-portal-hyprland
      systemctl --user stop xdg-desktop-portal-gtk
      systemctl --user stop xdg-desktop-portal
      echo "Start the desktop portal services..."
      systemctl --user start xdg-desktop-portal-hyprland
      systemctl --user start xdg-desktop-portal-gtk
      systemctl --user start xdg-desktop-portal
      pgrep --list-full xdg-desktop
    '';
  };
in
{
  home.packages = with pkgs; [ portalProdder ];

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
    plugins = with pkgs; [ hyprlandPlugins.hyprtrails ];
    settings = {
      inherit (monitors) monitor;
      "$mod" = "SUPER";
      # Work when input inhibitor (l) is active.
      bindl = [
        ", XF86AudioPlay, exec, ${lib.getExe pkgs.playerctl} play-pause"
        ", XF86AudioPrev, exec, ${lib.getExe pkgs.playerctl} previous"
        ", XF86AudioNext, exec, ${lib.getExe pkgs.playerctl} next"
      ];
      # https://en.wikipedia.org/wiki/Table_of_keyboard_shortcuts
      bindm = [
        # Move windows with AltGr + LMB (for lefties) and $mod + LMB
        "$mod, mouse:272, movewindow"
        "Mod5, mouse:272, movewindow"
      ];
      bind =
        [
          # Process management
          "$mod, Q, killactive"
          # Launch applications
          "$mod, E, exec, nautilus --new-window"
          "$mod, T, exec, alacritty"
          # Move focus
          "ALT, Tab, cyclenext"
          "ALT, Tab, bringactivetotop"
          "ALT SHIFT, Tab, cyclenext, prev"
          "ALT SHIFT, Tab, bringactivetotop"
          # Move focus with SHIFT + arrow keys
          "ALT, left, movefocus, l"
          "ALT, right, movefocus, r"
          "ALT, up, movefocus, u"
          "ALT, down, movefocus, d"
          "ALT $mod, left, swapwindow, l"
          "ALT $mod, right, swapwindow, r"
          "ALT $mod, up, swapwindow, u"
          "ALT $mod, down, swapwindow, d"
          "$mod, up, fullscreen, 1"
          "$mod, down, togglefloating"
          "$mod, P, pseudo"
          # Switch workspace
          "CTRL ALT, left, workspace, e-1"
          "CTRL ALT, right, workspace, e+1"
        ]
        ++ (
          # workspaces
          # binds ctrl + alt + {1..8} to switch to workspace {1..8}
          # binds $mod + alt + {1..8} to move window to workspace {1..8}
          builtins.concatLists (
            builtins.genList (
              x:
              let
                ws =
                  let
                    c = (x + 1) / 9;
                  in
                  builtins.toString (x + 1 - (c * 9));
              in
              [
                "CTRL ALT, ${ws}, workspace, ${toString (x + 1)}"
                "$mod ALT,  ${ws}, movetoworkspace, ${toString (x + 1)}"
              ]
            ) 9
          )
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
        "border, 1, 10, liner"
        "borderangle, 1, 100, linear, loop"
        "fade, 1, 10, default"
        "workspaces, 1, 5, wind"
      ];
      bezier = [
        "wind, 0.05, 0.9, 0.1, 1.05"
        "winIn, 0.1, 1.1, 0.1, 1.1"
        "winOut, 0.3, -0.3, 0, 1"
        "liner, 1, 1, 1, 1"
        "linear, 0.0, 0.0, 1.0, 1.0"
      ];
      decoration = {
        rounding = 8;
        active_opacity = 1.0;
        inactive_opacity = 1.0;
        fullscreen_opacity = 1.0;
        dim_inactive = true;
        dim_strength = 0.025;
        # Subtle shadows
        "col.shadow" = "rgba(11111baf)";
        "col.shadow_inactive" = "rgba(1e1e2eaf)";
        drop_shadow = true;
        shadow_range = 304;
        shadow_render_power = 4;
        shadow_offset = "0, 42";
        shadow_scale = 0.9;
        blur = {
          enabled = true;
          passes = 3;
          contrast = 0.8916;
          brightness = 0.8172;
          vibrancy = 0.1696;
          vibrancy_darkness = 0.0;
          ignore_opacity = true;
        };
      };
      exec-once = [
        "sleep 0.25 && hyprctl dispatch workspace 1"
        "sleep 1 && trayscale --gapplication-service --hide-window"
        #"sleep 1 && hyprctl dispatch exec [workspace 1 silent] brave"
        #"sleep 2 && hyprctl dispatch exec [workspace 2 silent] wavebox"
        #"sleep 2 && hyprctl dispatch exec [workspace 2 silent] discord"
        #"sleep 3 && hyprctl dispatch exec [workspace 3 silent] telegram-desktop"
        #"sleep 3 && hyprctl dispatch exec [workspace 3 silent] fractal"
        #"sleep 4 && hyprctl dispatch exec [workspace 4 silent] code"
        #"sleep 4 && hyprctl dispatch exec [workspace 4 silent] gitkraken"
        #"sleep 5 && hyprctl dispatch exec [workspace 5 silent] alacritty"
      ];
      general = {
        gaps_in = 5;
        gaps_out = 5;
        border_size = 2;
        # https://wiki.hyprland.org/Configuring/Variables/#variable-types for info about colors
        "col.active_border" = "rgb(cba6f7) rgb(f38ba8) rgb(eba0ac) rgb(fab387) rgb(f9e2af) rgb(a6e3a1) rgb(94e2d5) rgb(89dceb) rgb(89b4fa) rgb(b4befe) 270deg";
        "col.inactive_border" = "rgb(45475a) rgb(313244) rgb(45475a) rgb(313244) 270deg";
        resize_on_border = true;
        extend_border_grab_area = 10;
        layout = "master";
      };
      #https://wiki.hyprland.org/Configuring/Master-Layout/
      master = {
        mfact = if (hostname == "vader" || hostname == "phasma") then 0.5 else 0.55;
        orientation = if hostname == "vader" then
          "top"
        else if hostname == "phasma" then
          "center"
        else
          "left";
      };
      # https://wiki.hyprland.org/Configuring/Dwindle-Layout/
      dwindle = {
        force_split = 1;
        preserve_split = true;
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
        animate_manual_resizes = false;
        background_color = "rgb(30, 30, 46)";
        disable_hyprland_logo = true;
        disable_splash_rendering = true;
        key_press_enables_dpms = true;
        mouse_move_enables_dpms = true;
        vfr = true;
      };
      plugin = {
        hyprtrails = {
          color = "rgba(a6e3a1aa)";
          bezier_step = 0.025; #0.025
          points_per_step = 2; #2
          history_points = 12; #20
          history_step = 2;    #2
        };
      };
      windowrulev2 = [
        # only allow shadows for floating windows
        "noshadow, floating:0"
        # make floating windows opaque
        "opacity 0.64, floating:1"

        # make pop-up file dialogs floating, centred, and pinned
        "float, title:(Open|Progress|Save File)"
        "center, title:(Open|Progress|Save File)"
        "pin, title:(Open|Progress|Save File)"
        "float, class:^(code)$"
        "center, class:^(code)$"
        "pin, class:^(code)$"

        # Apps that should be floating
        "float, title:(Maestral Settings|MainPicker|overskride|Pipewire Volume Control|Trayscale)"
        "center, title:(Maestral Settings|MainPicker|overskride|Pipewire Volume Control|Trayscale)"
        "float, initialTitle:(Polychromatic|Syncthing Tray)"
        "center, initialTitle:(Polychromatic|Syncthing Tray)"
        "float, class:(nm-connection-editor|polkit-gnome-authentication-agent-1)"
        "center, class:(nm-connection-editor|polkit-gnome-authentication-agent-1)"
        "size 600 402, title:(Maestral Settings)"
        "size 512 290, title:(MainPicker)"
        "size 700 500, class:(nm-connection-editor)"
        "size 1134 880, title:(Pipewire Volume Control)"
        "size 960 640 initialTitle:(Polychromatic)"
        "size 880 1010, title:(overskride)"
        "size 886 960, title:(Trayscale)"
      ];
      layerrule = [
        "blur, logout_dialog" # wlogout
        "blur, swaync-control-center"
        "blur, swaync-notification-window"
        "ignorealpha 0.6, swaync-control-center"
        "ignorealpha 0.6, swaync-notification-window"
      ];
      # Simulate static workspaces
      workspace = [
        "1, name:Web, persistent:true, monitor:*"
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
  # https://github.com/hyprwm/hyprland-wiki/issues/409
  # https://github.com/nix-community/home-manager/pull/4707
  xdg.portal = {
    config = {
      common = {
        default = [ "hyprland" "gtk" ];
        "org.freedesktop.impl.portal.Secret" = [ "gnome-keyring" ];
      };
    };
    configPackages = [ config.wayland.windowManager.hyprland.package ];
    enable = true;
    extraPortals = [
      pkgs.xdg-desktop-portal
      pkgs.xdg-desktop-portal-gtk
      pkgs.xdg-desktop-portal-hyprland
    ];
    xdgOpenUsePortal = true;
  };
}
