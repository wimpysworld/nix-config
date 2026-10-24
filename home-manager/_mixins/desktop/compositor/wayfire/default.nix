{
  catppuccinPalette,
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  compositor = (import ../../../../../lib/wayland-compositors.nix).compositors.wayfire;
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
  # Wayfire and the clients it starts find the desktop GSettings schemas
  # through XDG_DATA_DIRS.
  wayfireWithGSettingsSchemas = pkgs.symlinkJoin {
    inherit (pkgs.wayfire) version;
    pname = "wayfire-with-gsettings-schemas";
    paths = [ pkgs.wayfire ];
    nativeBuildInputs = [ pkgs.makeWrapper ];

    postBuild = ''
      wrapProgram $out/bin/wayfire \
        --prefix XDG_DATA_DIRS : ${pkgs.glib.makeSchemaDataDirPath pkgs.gsettings-desktop-schemas pkgs.gsettings-desktop-schemas.name}
    '';

    passthru = pkgs.wayfire.passthru // {
      unwrapped = pkgs.wayfire;
    };

    meta = pkgs.wayfire.meta // {
      outputsToInstall = [ "out" ];
    };
  };
  launcherLayers = [
    "launcher"
    "rofi"
  ];
  blurredLayers = launcherLayers ++ [
    "swayosd"
    "wleave"
  ];
  matchLayers = namespaces: lib.concatMapStringsSep " | " (n: ''app_id is "${n}"'') namespaces;
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

    systemd.user.targets.wayfire-session.Unit.Wants = [ "xdg-desktop-autostart.target" ];

    wayland.windowManager.wayfire = {
      enable = true;
      package = wayfireWithGSettingsSchemas;
      plugins = with pkgs.wayfirePlugins; [
        wcm
        wayfire-plugins-extra
        pkgs.vecdecor
      ];
      systemd = {
        variables = compositor.startupEnvironment;
        extraCommands = [ "wayland-session start" ];
      };
      settings = {
        # Window animations. The launchers zoom like they do on Mango, and
        # other overlay surfaces, including wleave, keep the default fade.
        # Wayfire checks fade before zoom, so fade excludes the launchers.
        animate = {
          open_animation = "zap";
          close_animation = "spin";
          duration = 300;
          fade_enabled_for = ''type is "overlay" & !(${matchLayers launcherLayers})'';
          zoom_enabled_for = ''!(type is "toplevel") & (${matchLayers launcherLayers})'';
          zoom_duration = "300ms circle";
        };
        autostart = {
          # Disable wf-shell autostart, we're using waybar et al instead
          autostart_wf_shell = false;
        };
        # Wayfire blurs only toplevels by default. Keep that, as Mango also
        # blurs behind windows, and add the translucent desktop shell layer
        # surfaces that Mango blurs; they match by app_id, which is their
        # layer-shell namespace. Blur only shows behind pixels that are
        # already translucent, so opaque windows look the same. SwayNC stays
        # unblurred, because its transparent shadow margin would blur into a
        # halo.
        blur = {
          blur_by_default = ''type is "toplevel" | (${matchLayers blurredLayers})'';
          # Dual kawase, tuned to reach about as far as Mango's scenefx blur
          # (3 passes at radius 8, about 112 px): 1.5 * offset * degrade *
          # (2^iterations - 1) = 112.5 px. Extra iterations run at a quarter
          # of the previous resolution, so they are the cheap way to widen
          # the blur. Degrade 2 keeps thin text strokes from turning to grain,
          # because Wayfire degrades with a nearest-pixel copy.
          method = "kawase";
          kawase_offset = 2.5;
          kawase_degrade = 2;
          kawase_iterations = 4;
          saturation = 1.0;
        };
        core = {
          plugins = "animate blur command cube expo foreign-toplevel grid gtk-shell idle ipc ipc-rules move vecdecor place resize session-lock shortcuts-inhibit stipc switcher vswipe vswitch winshadows wm-actions wobbly xdg-activation";
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
        vecdecor = {
          bg_color = toWayfireColor "base" 1.0;
          bg_text_color = "0.527451 0.531373 0.570588 1.0";
          border_size = 2;
          button_close_svg = "";
          button_color = toWayfireColor "text" 1.0;
          button_hover_color = toWayfireColor "surface0" 1.0;
          button_inactive_color = "0.529412 0.533333 0.572549 1.0";
          button_line_thickness = 1.0;
          button_maximize_svg = "";
          button_minimize_svg = "";
          button_pressed_color = toWayfireColor "surface1" 1.0;
          button_restore_svg = "";
          left_button_spacing = 16;
          left_button_x_offset = 0;
          right_button_spacing = 16;
          right_button_x_offset = -8;
          fg_color = toWayfireColor "mantle" 1.0;
          fg_text_color = toWayfireColor "text" 1.0;
          rounded_corner_radius = 10;
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
          # A soft, centred black glow with no offset. The intensity and
          # radius are tuned by eye to look like the Mango crust shadow
          # (shadows_color in mango/theme.nix), so they are Wayfire settings
          # and not a shared alpha level.
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
          # Disable the cube screensaver; Veila owns the idle fade and lock.
          screensaver_timeout = -1;
          dpms_timeout = 600;
        };
        input = {
          xkb_layout = host.keyboard.layout;
          repeat_delay = 300;
          repeat_rate = config.noughty.user.keyboard.repeatRate;
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
  };
}
