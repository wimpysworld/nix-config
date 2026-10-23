{
  catppuccinPalette,
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  cfg = config.wayland.windowManager.mango;
  inherit (import ./config-format.nix { inherit catppuccinPalette lib; }) floatStr toMangoConf;

  mkMonitorRule =
    d:
    "name:^${d.output}$,width:${toString d.width},height:${toString d.height},refresh:${toString d.refresh},x:${toString d.position.x},y:${toString d.position.y},scale:${floatStr d.scale}"
    + lib.optionalString d.primary ",primary:1";

  sessionAdapter = pkgs.writeShellApplication {
    name = "wayland-session-adapter";
    runtimeInputs = [
      cfg.package
    ]
    ++ (with pkgs; [
      coreutils
      jq
      wayland-logout
      wlrctl
    ]);
    text = builtins.readFile ./wayland-session-adapter.sh;
  };
in
{
  imports = [
    ./bindings.nix
    ./options.nix
    ./rules.nix
    ./theme.nix
    ./waybar.nix
  ];

  config = lib.mkIf (host.desktop == "mango") {
    assertions = [
      {
        assertion = lib.versions.majorMinor cfg.package.version == "0.18";
        message = "Mango ${cfg.package.version} is not 0.18. Review the renamed configuration keys in home-manager/_mixins/desktop/compositor/mango before you accept this version, then update this assertion.";
      }
    ];

    home.packages = [
      cfg.package
      sessionAdapter
    ];

    # Mango starts graphical-session.target before `wayland-session start`
    # imports the contract environment, so set this one early.
    systemd.user.sessionVariables.NIXOS_OZONE_WL = "1";

    systemd.user.targets.mangowm-session = {
      Unit = {
        Description = "Mango compositor session";
        Documentation = [ "man:systemd.special(7)" ];
        BindsTo = [ "graphical-session.target" ];
        Wants = [
          "graphical-session-pre.target"
          "xdg-desktop-autostart.target"
        ];
        After = [ "graphical-session-pre.target" ];
      };
    };

    wayland.windowManager.mango = {
      enable = true;
      settings = {
        xkb_rules_layout = host.keyboard.layout;
        xkb_rules_variant = host.keyboard.variant;
        repeat_rate = config.noughty.user.keyboard.repeatRate;
        repeat_delay = 300;
        numlock_on = false;
        tap_to_click = true;
        tap_and_drag = true;
        drag_lock = false;
        trackpad_natural_scrolling = true;
        trackpad_middle_button_emulation = true;
        trackpad_click_method = 2;
        trackpad_disable_while_typing = true;
        mouse_natural_scrolling = false;
        # Focus changes on a click.
        # Focus that follows the pointer would take focus away from the
        # window that ALT+Tab selects, because the pointer stays put.
        sloppy_focus = false;
        focus_on_activate = true;
        warp_cursor = false;
        drag_warp_cursor = true;
        cursor_theme = config.home.pointerCursor.name;
        cursor_size = config.home.pointerCursor.size;
        xwayland_ignore_scale = true;
        idle_inhibit_when_fullscreen = true;
        focus_cross_monitor = host.display.isMultiMonitor;
        exchange_cross_monitor = host.display.isMultiMonitor;
        focus_cross_tag = false;
        view_current_to_back = false;
        tag_carousel = false;
        enable_border_resize = true;
        border_resize_size = 10;
        auto_reload_config = true;
        tag_num = 8;
        enable_hotarea = false;
        new_is_master = true;
        dwindle_preserve_split = true;
        dwindle_smart_split = false;
        tag_rule = [ "id:*,layout_name:dwindle" ];
        monitor_rule = map mkMonitorRule host.displays;
        exec_once = [ "wayland-session start" ];
      };
    };

    xdg = {
      configFile."mango/config.conf".source =
        pkgs.runCommand "mango-config.conf"
          {
            nativeBuildInputs = [ cfg.package ];
            text = toMangoConf cfg.settings cfg.keymodes cfg.extraConfig;
            passAsFile = [ "text" ];
          }
          ''
            cp "$textPath" "$out"
            XDG_RUNTIME_DIR="$TMPDIR" mango -p -c "$out"
          '';
    };
  };
}
