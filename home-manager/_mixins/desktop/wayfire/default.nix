{
  lib,
  pkgs,
  ...
}:
{
  wayland.windowManager.wayfire = {
    enable = true;
    settings = {
      # Core plugins - essential window management functionality
      core = {
        plugins = "autostart command vswitch move resize grid wm-actions decoration place animate";
        # Virtual desktop configuration - 8 workspaces in a single row
        vwidth = 8;
        vheight = 1;
      };

      # Autostart configuration
      autostart = {
        # Launch rofi on startup (hidden, ready for Super to show)
        rofi = false; # We'll trigger rofi via keybinding instead
      };

      # Command bindings - Super+T for terminal, Super for rofi
      command = {
        # Super+T launches kitty terminal
        binding_terminal = "<super> KEY_T";
        command_terminal = "${lib.getExe pkgs.kitty}";

        # Super key toggles rofi launcher
        binding_launcher = "<super>";
        command_launcher = "${lib.getExe pkgs.unstable.rofi} -show drun";
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
      };

      # Window movement - Super+Left Mouse to drag windows
      move = {
        activate = "<super> BTN_LEFT";
        enable_snap = true;
        enable_snap_off = true;
        snap_threshold = 10;
        snap_off_threshold = 10;
      };

      # Window resizing - Super+Right Mouse to resize windows
      resize = {
        activate = "<super> BTN_RIGHT";
      };

      # Grid snapping - position windows in screen regions
      grid = {
        duration = 300;
        type = "crossfade";
        # Slot keybindings for window positioning
        slot_l = "<super> KEY_LEFT"; # Snap to left half
        slot_r = "<super> KEY_RIGHT"; # Snap to right half
        #slot_t = "<super> KEY_UP"; # Snap to top half
        #slot_b = "<super> KEY_DOWN"; # Snap to bottom half
        #slot_c = "<super> KEY_C"; # Center/maximize
        #slot_tl = "<super> <shift> KEY_UP"; # Top-left quarter
        #slot_tr = "<super> <ctrl> KEY_UP"; # Top-right quarter
        #slot_bl = "<super> <shift> KEY_DOWN"; # Bottom-left quarter
        #slot_br = "<super> <ctrl> KEY_DOWN"; # Bottom-right quarter
        restore = "<super> KEY_BACKSPACE"; # Restore original size
      };

      # Window management actions
      wm-actions = {
        #toggle_fullscreen = "<super> KEY_F";
        toggle_maximize = "<super> KEY_UP";
        #minimize = "<super> KEY_N";
        #toggle_always_on_top = "<super> KEY_A";
        #toggle_sticky = "<super> KEY_S";
      };

      # Window placement for new windows
      place = {
        mode = "center"; # Center new windows
      };

      # Window animations
      animate = {
        open_animation = "zoom";
        close_animation = "zoom";
        duration = 300;
      };

      # Window decorations (title bars, borders)
      decoration = {
        active_color = "0.6 0.6 0.6 1.0";
        inactive_color = "0.3 0.3 0.3 1.0";
        border_size = 4;
        title_height = 30;
      };
    };
    xwayland.enable = true;
  };
}
