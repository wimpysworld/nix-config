{
  catppuccinPalette,
  config,
  hostname,
  lib,
  pkgs,
  ...
}:
let
  xkbLayout = "gb";
  monitors =
    (import ./monitors.nix { }).${hostname} or {
      monitor = [ ", preferred, auto, 1" ];
      workspace = [ ];
    };
in
{
  catppuccin = {
    hyprland.enable = config.wayland.windowManager.hyprland.enable;
  };

  home.packages = with pkgs; [
    hyprpicker
    wayvnc
    wdisplays
  ];
  # Hyprland is a Wayland compositor and dynamic tiling window manager
  # Additional applications are required to create a full desktop shell
  imports = [
    ../components/avizo # on-screen display for audio and backlight
    ../components/fuzzel # app launcher, emoji picker and clipboard manager
    ../components/hyprlock # screen locker
    ../components/hyprpaper # wallpaper setter
    ../components/hyprshot # screenshot grabber and annotator
    ../components/rofi # application launcher
    ../components/swaync # notification center
    ../components/waybar # status bar
    ../components/wlogout # session menu
  ];
  services = {
    # Not in home-manager 25.04
    #wayvnc = {
    #  autoStart = true;
    #  enable = true;
    #  settings = {
    #    address = "0.0.0.0";
    #    port = 5900;
    #  };
    #};
  };

  wayland.windowManager.hyprland = {
    enable = true;
    settings = {
      inherit (monitors) monitor workspace;
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
        "$mod, mouse:273, resizewindow"
        "Mod5, mouse:272, movewindow"
        "Mod5, mouse:273, resizewindow"
      ];
      bind = [
        # Process management
        "$mod, Q, killactive"
        # Launch applications
        "$mod, E, exec, ${pkgs.nautilus}/bin/nautilus --new-window"
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
        "CTRL ALT, 1, workspace, 1"
        "$mod ALT, 1, movetoworkspace, 1"
        "CTRL ALT, 2, workspace, 2"
        "$mod ALT, 2, movetoworkspace, 2"
        "CTRL ALT, 3, workspace, 3"
        "$mod ALT, 3, movetoworkspace, 3"
        "CTRL ALT, 4, workspace, 4"
        "$mod ALT, 4, movetoworkspace, 4"
        "CTRL ALT, 5, workspace, 5"
        "$mod ALT, 5, movetoworkspace, 5"
        "CTRL ALT, 6, workspace, 6"
        "$mod ALT, 6, movetoworkspace, 6"
        "CTRL ALT, 7, workspace, 7"
        "$mod ALT, 7, movetoworkspace, 7"
        "CTRL ALT, 8, workspace, 8"
        "$mod ALT, 8, movetoworkspace, 8"
        "CTRL ALT, 9, workspace, 9"
        "$mod ALT, 9, movetoworkspace, 9"
      ];
      # https://wiki.hyprland.org/Configuring/Variables/#animations
      animations = {
        enabled = true;
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
        shadow = {
          # Subtle shadows
          color = "rgba(${catppuccinPalette.getHyprlandColor "crust"}af)";
          color_inactive = "rgba(${catppuccinPalette.getHyprlandColor "base"}af)";
          enabled = true;
          range = 304;
          render_power = 4;
          offset = "0, 42";
          scale = 0.9;
        };
        blur = {
          enabled = true;
          passes = 2;
          size = 6;
          ignore_opacity = true;
        };
      };
      exec-once = [
        "hypr-session start"
        #"wayvnc 0.0.0.0"
      ];
      general = {
        gesture = "3, horizontal, workspace";
        gaps_in = 5;
        gaps_out = 5;
        border_size = 2;
        # https://wiki.hyprland.org/Configuring/Variables/#variable-types for info about colors
        "col.active_border" =
          "rgb(${catppuccinPalette.getHyprlandColor "mauve"}) rgb(${catppuccinPalette.getHyprlandColor "red"}) rgb(${catppuccinPalette.getHyprlandColor "maroon"}) rgb(${catppuccinPalette.getHyprlandColor "peach"}) rgb(${catppuccinPalette.getHyprlandColor "yellow"}) rgb(${catppuccinPalette.getHyprlandColor "green"}) rgb(${catppuccinPalette.getHyprlandColor "teal"}) rgb(${catppuccinPalette.getHyprlandColor "sky"}) rgb(${catppuccinPalette.getHyprlandColor "blue"}) rgb(${catppuccinPalette.getHyprlandColor "lavender"}) 270deg";
        "col.inactive_border" =
          "rgb(${catppuccinPalette.getHyprlandColor "surface2"}) rgb(${catppuccinPalette.getHyprlandColor "surface1"}) rgb(${catppuccinPalette.getHyprlandColor "surface2"}) rgb(${catppuccinPalette.getHyprlandColor "surface1"}) 270deg";
        resize_on_border = true;
        extend_border_grab_area = 10;
        layout = "dwindle";
      };
      #https://wiki.hyprland.org/Configuring/Master-Layout/
      master = {
        mfact = if hostname == "phasma" then 0.5 else 0.55;
        orientation = if hostname == "phasma" then "center" else "left";
      };
      # https://wiki.hyprland.org/Configuring/Dwindle-Layout/
      dwindle = {
        preserve_split = true;
      };
      group = {
        groupbar = {
          font_family = config.gtk.font.name or "Work Sans";
          font_size = config.gtk.font.size or 13;
          gradients = true;
        };
      };
      input = {
        follow_mouse = 2;
        kb_layout = xkbLayout;
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
        background_color = "rgb(${catppuccinPalette.getHyprlandColor "base"})";
        disable_hyprland_logo = true;
        disable_splash_rendering = true;
        focus_on_activate = true;
        key_press_enables_dpms = true;
        mouse_move_enables_dpms = true;
        vfr = true;
      };
      plugin = {
        hyprtrails = {
          color = "rgba(${catppuccinPalette.getHyprlandColor "green"}aa)";
          bezier_step = 0.025; # 0.025
          points_per_step = 2; # 2
          history_points = 12; # 20
          history_step = 2; # 2
        };
      };
      windowrulev2 = [
        # only allow shadows for floating windows
        "noshadow, floating:0"
        # make floating windows opaque
        "opacity 0.72, floating:1"
        # Some windows should never be opaque
        "opacity 1.0, class: com.obsproject.Studio"
        "opacity 1.0, class: resolve"
        "opacity 1.0, class: com.defold.editor.Start"
        "opacity 1.0, class: class: dmengine"
        "opacity 1.0, title: UNIGINE Engine"
        "opacity 1.0, title: Steam Big Picture Mode"
        "opacity 1.0, class: Gimp"
        "opacity 1.0, class: love"
        "opacity 1.0, title: ^QEMU"

        # make pop-up file dialogs floating, centred, and pinned
        "float, title:(Open|Progress|Save File)"
        "center, title:(Open|Progress|Save File)"
        "pin, title:(Open|Progress|Save File)"
        "float, class:(xdg-desktop-portal-gtk)"
        "center, class:(xdg-desktop-portal-gtk)"
        "pin, class:(xdg-desktop-portal-gtk)"
        "float, class:^(code)$, initialTitle:not:Visual Studio Code"
        "center, class:^(code)$, initialTitle:not:Visual Studio Code"
        "pin, class:^(code)$, initialTitle:not:Visual Studio Code"

        # Apps that should be floating
        "float, title:(Maestral Settings|MainPicker|overskride|Pipewire Volume Control|Trayscale)"
        "center, title:(Maestral Settings|MainPicker|overskride|Pipewire Volume Control|Trayscale)"
        "float, initialTitle:(Polychromatic|Syncthing Tray)"
        "center, initialTitle:(Polychromatic|Syncthing Tray)"
        "float, class:(.blueman-manager-wrapped|blueberry.py|nm-connection-editor|org.gnome.Calculator|polkit-gnome-authentication-agent-1)"
        "center, class:(.blueman-manager-wrapped|blueberry.py|nm-connection-editor|org.gnome.Calculator|polkit-gnome-authentication-agent-1)"
        "size 700 580, title:(.blueman-manager-wrapped)"
        "size 580 640, title:(blueberry.py)"
        "size 600 402, title:(Maestral Settings)"
        "size 512 290, title:(MainPicker)"
        "size 395 496, class:(org.gnome.Calculator)"
        "size 700 500, class:(nm-connection-editor)"
        "size 1134 880, title:(Pipewire Volume Control)"
        "size 960 640, initialTitle:(Polychromatic)"
        "size 880 1010, title:(overskride)"
        "size 886 960, title:(Trayscale)"

        # Apps for streaming from dummy workspace
        "float, onworkspace:10"
        "opacity 1.0 0.6 1.0, onworkspace:10"
        "size 1596 1076, onworkspace:10"
        "maxsize 1596 1076, onworkspace:10"
        "minsize 1596 1076, onworkspace:10"
        "move 322 2, onworkspace:10"
        "noshadow, onworkspace:10"
      ];
      layerrule = [
        "blur, launcher" # fuzzel
        "ignorezero, launcher"
        "blur, logout_dialog" # wlogout
        "blur, rofi"
        "blur, swaync-control-center"
        "blur, swaync-notification-window"
        "ignorealpha 0.7, swaync-control-center"
        "ignorealpha 0.7, swaync-notification-window"
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
  xdg = {
    portal = {
      config = {
        common = {
          # Hyprland-specific interfaces
          "org.freedesktop.impl.portal.ScreenCast" = [ "hyprland" ];
          "org.freedesktop.impl.portal.Screenshot" = [ "hyprland" ];
        };
      };
      configPackages = [ config.wayland.windowManager.hyprland.package ];
    };
  };
}
