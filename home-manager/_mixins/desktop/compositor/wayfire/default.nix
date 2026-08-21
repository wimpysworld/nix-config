{
  catppuccinPalette,
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  toWayfireColor =
    color: alpha:
    let
      hex = catppuccinPalette.getColor color;
      red = builtins.substring 1 2 hex;
      green = builtins.substring 3 2 hex;
      blue = builtins.substring 5 2 hex;
      toFloat = hexString: toString (builtins.div (builtins.fromTOML "value=0x${hexString}").value 255.0);
    in
    "${toFloat red} ${toFloat green} ${toFloat blue} ${toString alpha}";
  pixdecorButtons = pkgs.pixdecor-catppuccin-buttons.override {
    activeGlyphColor = catppuccinPalette.getColor "text";
    inactiveCircleColor = catppuccinPalette.getColor "surface1";
    inactiveGlyphColor = "#878892";
    hoverBackgroundColor = catppuccinPalette.getColor "surface0";
    minimiseCircleColor = catppuccinPalette.getColor "yellow";
    maximiseCircleColor = catppuccinPalette.getColor "green";
    closeCircleColor = catppuccinPalette.getColor "red";
  };
  pixdecorButtonPath = "${pixdecorButtons}/share/pixdecor/buttons";
  sessionAdapter = pkgs.writeShellApplication {
    name = "wayland-session-adapter";
    runtimeInputs = with pkgs; [
      coreutils
      wayland-logout
      wlrctl
    ];
    text = builtins.readFile ./wayland-session-adapter.sh;
  };
in
{
  imports = [ ./bindings.nix ];

  config = lib.mkIf (host.desktop == "wayfire") {
    #TODO: IPC tooling for wayfire
    # https://github.com/killown/wayfire-rs
    # https://github.com/AR-CADE/wayfire-ipc
    # https://github.com/bluebyt/Wayfire-dots/tree/main/.config/ipc-scripts
    home.packages = with pkgs; [
      sessionAdapter
      wayland-logout
    ];

    programs.ghostty.settings.window-decoration = lib.mkForce "server";

    wayland.windowManager.wayfire = {
      enable = true;
      plugins = with pkgs.wayfirePlugins; [
        wcm
        wayfire-plugins-extra
      ];
      systemd.variables = [
        "DISPLAY"
        "WAYLAND_DISPLAY"
        "XDG_CURRENT_DESKTOP"
        "NIXOS_OZONE_WL"
        "XCURSOR_THEME"
        "XCURSOR_SIZE"
        "WAYFIRE_SOCKET"
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
          session = "wayland-session start";
        };
        core = {
          plugins = "animate autostart blur command cube expo foreign-toplevel grid gtk-shell idle ipc ipc-rules move pixdecor place resize session-lock switcher vswipe vswitch winshadows wm-actions wobbly xdg-activation";
          preferred_decoration_mode = "server";
          vwidth = 8;
          vheight = 1;
        };
        cube = {
          activate = "none";
          rotate_left = "<ctrl> <alt> KEY_LEFT";
          rotate_right = "<ctrl> <alt> KEY_RIGHT";
        };
        expo.toggle = "<super> KEY_HOME";
        pixdecor = {
          bg_color = toWayfireColor "base" 1.0;
          bg_text_color = "0.527451 0.531373 0.570588 1.0";
          border_size = 2;
          button_color = toWayfireColor "text" 1.0;
          button_close_hover_image = "${pixdecorButtonPath}/close-hover.png";
          button_close_image = "${pixdecorButtonPath}/close.png";
          button_close_inactive_hover_image = "${pixdecorButtonPath}/close-inactive-hover.png";
          button_close_inactive_image = "${pixdecorButtonPath}/close-inactive.png";
          button_line_thickness = 1.0;
          button_maximize_hover_image = "${pixdecorButtonPath}/maximize-hover.png";
          button_maximize_image = "${pixdecorButtonPath}/maximize.png";
          button_maximize_inactive_hover_image = "${pixdecorButtonPath}/maximize-inactive-hover.png";
          button_maximize_inactive_image = "${pixdecorButtonPath}/maximize-inactive.png";
          button_minimize_hover_image = "${pixdecorButtonPath}/minimize-hover.png";
          button_minimize_image = "${pixdecorButtonPath}/minimize.png";
          button_minimize_inactive_hover_image = "${pixdecorButtonPath}/minimize-inactive-hover.png";
          button_minimize_inactive_image = "${pixdecorButtonPath}/minimize-inactive.png";
          button_restore_hover_image = "${pixdecorButtonPath}/restore-hover.png";
          button_restore_image = "${pixdecorButtonPath}/restore.png";
          button_restore_inactive_hover_image = "${pixdecorButtonPath}/restore-inactive-hover.png";
          button_restore_inactive_image = "${pixdecorButtonPath}/restore-inactive.png";
          left_button_spacing = 16;
          left_button_x_offset = 0;
          fg_color = toWayfireColor "mantle" 1.0;
          fg_text_color = toWayfireColor "text" 1.0;
          overlay_engine = "rounded_corners";
          right_button_spacing = 16;
          right_button_x_offset = -16;
          rounded_corner_radius = 10;
          shadow_color = toWayfireColor "crust" 0.4;
          shadow_radius = 0;
          title_height = 46;
          title_font = "${config.gtk.font.name} Bold ${toString config.gtk.font.size}";
          titlebar = true;
        };
        winshadows = {
          clip_shadow_inside = false;
          enabled_views = ''type is "toplevel" & floating is true'';
          glow_color = "0.0 0.0 0.0 1.0";
          glow_emissivity = 0.0;
          glow_enabled = true;
          glow_intensity = 0.45;
          # The glow has no offset, so 35 pixels is the midpoint between GTK4's 30-pixel side and 40-pixel lower extents.
          glow_radius_limit = 35;
          glow_spread = 5.0;
          glow_threshold = 0.09;
          horizontal_offset = 0;
          include_undecorated_views = false;
          light_type = "gaussian";
          overscale = 0.0;
          shadow_color = "0.0 0.0 0.0 0.0";
          shadow_radius = 1;
          vertical_offset = 0;
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
          slot_c = "none";
          #slot_tl = "<super> <shift> KEY_UP"; # Top-left quarter
          #slot_tr = "<super> <ctrl> KEY_UP"; # Top-right quarter
          #slot_bl = "<super> <shift> KEY_DOWN"; # Bottom-left quarter
          #slot_br = "<super> <ctrl> KEY_DOWN"; # Bottom-right quarter
          restore = "none";
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
        vswipe = {
          enable_horizontal = true;
          enable_vertical = false;
          fingers = 3;
        };
        # Virtual desktop switching with Ctrl+Alt+[1-8]
        vswitch = {
          duration = 0;
          binding_1 = "<ctrl> <alt> KEY_1";
          binding_2 = "<ctrl> <alt> KEY_2";
          binding_3 = "<ctrl> <alt> KEY_3";
          binding_4 = "<ctrl> <alt> KEY_4";
          binding_5 = "<ctrl> <alt> KEY_5";
          binding_6 = "<ctrl> <alt> KEY_6";
          binding_7 = "<ctrl> <alt> KEY_7";
          binding_8 = "<ctrl> <alt> KEY_8";
          binding_down = "none";
          binding_last = "none";
          binding_left = "none";
          binding_right = "none";
          binding_up = "none";
          send_win_down = "none";
          send_win_last = "none";
          send_win_left = "none";
          send_win_right = "none";
          send_win_up = "none";
          with_win_down = "none";
          with_win_last = "none";
          with_win_left = "none";
          with_win_right = "none";
          with_win_up = "none";
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
