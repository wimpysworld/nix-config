{
  catppuccinPalette,
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
in
{
  imports = [
    ../components/avizo
    ../components/fuzzel
    ../components/hyprpaper
    ../components/rofi
    ../components/swaync
    ../components/waybar
    ../components/wlogout
  ];

  config = lib.mkIf (host.desktop == "wayfire") {
    #TODO: IPC tooling for wayfire
    # https://github.com/killown/wayfire-rs
    # https://github.com/AR-CADE/wayfire-ipc
    # https://github.com/bluebyt/Wayfire-dots/tree/main/.config/ipc-scripts
    # TODO: pixdecor
    # https://github.com/soreau/pixdecor
    # https://github.com/NixOS/nixpkgs/pull/355376
    # https://github.com/NixOS/nixpkgs/pull/355376#issuecomment-3290317610
    # TODO: Wayfire 0.10.0
    # Integrate this patch for colour picking support
    # https://github.com/WayfireWM/wayfire/pull/2852

    home.packages = with pkgs; [
      wayland-logout
    ];

    wayland.windowManager.wayfire = {
      enable = true;
      plugins = with pkgs.wayfirePlugins; [
        wcm
        wayfire-plugins-extra
      ];
      settings = {
        # Window animations
        animate = {
          open_animation = "zap";
          close_animation = "spin";
          duration = 300;
        };
        autostart = {
          # Disable wf-shell autostart, we're using waybar et al instead
          autostart_wf_shell = false;
          bar = "${pkgs.waybar}/bin/waybar";
          button_layout = "dconf write /org/gnome/desktop/wm/preferences/button-layout \"':close,minimize,maximize'\"";
        };
        command = {
          # Super+E launches the file manager
          binding_files = "<super> KEY_E";
          command_files = "${lib.getExe pkgs.nautilus} --new-window";
          # Media controls
          binding_play_pause = "KEY_PLAYPAUSE";
          command_play_pause = "${lib.getExe pkgs.playerctl} play-pause";
          binding_previous = "KEY_PREVIOUS";
          command_previous = "${lib.getExe pkgs.playerctl} previous";
          binding_next = "KEY_NEXT";
          command_next = "${lib.getExe pkgs.playerctl} next";
        };
        core = {
          plugins = "animate autostart blur command decoration foreign-toplevel grid gtk-shell idle ipc ipc-rules move place resize session-lock switcher vswitch wm-actions wobbly xdg-activation";
          preferred_decoration_mode = "client";
          vwidth = 8;
          vheight = 1;
        };
        # Window decorations (title bars, borders)
        decoration = {
          # Active window: use mantle colour for visibility against surface
          active_color =
            let
              hex = catppuccinPalette.getColor "mantle";
              r = builtins.substring 1 2 hex;
              g = builtins.substring 3 2 hex;
              b = builtins.substring 5 2 hex;
              toFloat = hexStr: toString (builtins.div (builtins.fromTOML "x=0x${hexStr}").x 255.0);
            in
            "${toFloat r} ${toFloat g} ${toFloat b} 1.0";

          # Inactive window: use base for subtle, recessed appearance
          inactive_color =
            let
              hex = catppuccinPalette.getColor "base";
              r = builtins.substring 1 2 hex;
              g = builtins.substring 3 2 hex;
              b = builtins.substring 5 2 hex;
              toFloat = hexStr: toString (builtins.div (builtins.fromTOML "x=0x${hexStr}").x 255.0);
            in
            "${toFloat r} ${toFloat g} ${toFloat b} 1.0";
          font = "Work Sans 12";
          border_size = 4;
          title_height = 30;
          button_order = "minimize maximize close";
        };
        # Grid snapping - position windows in screen regions
        grid = {
          duration = 300;
          type = "crossfade";
          # Slot keybindings for window positioning
          slot_l = "<super> <alt> KEY_LEFT"; # Snap to left half
          slot_r = "<super> <alt> KEY_RIGHT"; # Snap to right half
          slot_t = "<super> <alt> KEY_UP"; # Snap to top half
          slot_b = "<super> <alt> KEY_DOWN"; # Snap to bottom half
          #slot_c = "<super> KEY_C"; # Center/maximize
          #slot_tl = "<super> <shift> KEY_UP"; # Top-left quarter
          #slot_tr = "<super> <ctrl> KEY_UP"; # Top-right quarter
          #slot_bl = "<super> <shift> KEY_DOWN"; # Bottom-left quarter
          #slot_br = "<super> <ctrl> KEY_DOWN"; # Bottom-right quarter
          restore = "<super> KEY_DOWN"; # Restore original size
        };
        idle = {
          toggle = "<super> KEY_Z";
          screensaver_timeout = 300;
          dpms_timeout = 600;
        };
        input = {
          xkb_layout = host.keyboard.layout;
          repeat_delay = 300;
          repeat_rate = 30;
          cursor_size = 32;
        };
        # Window movement - Super+Left Mouse to drag windows
        move = {
          activate = "<super> BTN_LEFT";
          enable_snap = true;
          enable_snap_off = true;
          snap_threshold = 10;
          snap_off_threshold = 10;
        };
        # Window placement for new windows
        place = {
          mode = "center";
        };
        # Window resizing - Super+Right Mouse to resize windows
        resize = {
          activate = "<super> BTN_RIGHT";
        };
        switcher = {
          next_view = "<alt> KEY_TAB";
          prev_view = "<alt> <shift> KEY_TAB";
        };
        # Virtual desktop switching with Ctrl+Alt+[1-8]
        vswitch = {
          binding_1 = "<ctrl> <alt> KEY_1";
          binding_2 = "<ctrl> <alt> KEY_2";
          binding_3 = "<ctrl> <alt> KEY_3";
          binding_4 = "<ctrl> <alt> KEY_4";
          binding_5 = "<ctrl> <alt> KEY_5";
          binding_6 = "<ctrl> <alt> KEY_6";
          binding_7 = "<ctrl> <alt> KEY_7";
          binding_8 = "<ctrl> <alt> KEY_8";
          binding_left = "<ctrl> <alt> KEY_LEFT";
          binding_right = "<ctrl> <alt> KEY_RIGHT";
          with_win_1 = "<super> <alt> KEY_1";
          with_win_2 = "<super> <alt> KEY_2";
          with_win_3 = "<super> <alt> KEY_3";
          with_win_4 = "<super> <alt> KEY_4";
          with_win_5 = "<super> <alt> KEY_5";
          with_win_6 = "<super> <alt> KEY_6";
          with_win_7 = "<super> <alt> KEY_7";
          with_win_8 = "<super> <alt> KEY_8";
        };
        # Window management actions
        wm-actions = {
          #toggle_fullscreen = "<super> KEY_F";
          toggle_maximize = "<super> KEY_UP";
          #minimize = "<super> KEY_N";
          #toggle_always_on_top = "<super> KEY_A";
          #toggle_sticky = "<super> KEY_S";
        };
      };
      xwayland.enable = true;
    };
    xdg = {
      portal = {
        config = {
          common = {
            "org.freedesktop.impl.portal.ScreenCast" = [ "wlr" ];
            "org.freedesktop.impl.portal.Screenshot" = [ "wlr" ];
          };
        };
        configPackages = [ config.wayland.windowManager.wayfire.package ];
      };
    };
  };
}
