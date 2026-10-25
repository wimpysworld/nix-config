{
  config,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  inherit (host) display;
  isHandyHost = host.is.linux && host.is.workstation && noughtyLib.hostHasTag "handy";
  inherit (pkgs) veila;
  veilaBin = lib.getExe' veila "veila";
  swayosdClient = lib.getExe' pkgs.swayosd "swayosd-client";
  # SwayOSD does not unmute on a volume change, so unmute the output first.
  unmuteOutput = "${lib.getExe' pkgs.wireplumber "wpctl"} set-mute @DEFAULT_AUDIO_SINK@ 0";
  binding = category: description: section: option: keys: {
    inherit
      category
      description
      section
      option
      keys
      ;
  };
  command =
    category: description: name: keys: action:
    (binding category description "command" "binding_${name}" keys)
    // {
      commandOption = "command_${name}";
      inherit action;
    };
  commands = [
    # Start Nautilus through PATH, so that the Home profile wrapper sets
    # its extension directory.
    (command "Application" "Open file manager" "files" "<super> KEY_E" "nautilus --new-window")
    (command "Media" "Play or pause media" "play_pause" "KEY_PLAYPAUSE"
      "${lib.getExe pkgs.playerctl} play-pause"
    )
    (command "Media" "Previous track" "previous" "KEY_PREVIOUS" "${lib.getExe pkgs.playerctl} previous")
    (command "Media" "Next track" "next" "KEY_NEXT" "${lib.getExe pkgs.playerctl} next")
    (command "Audio" "Toggle output mute" "mute" "KEY_MUTE"
      "${swayosdClient} --output-volume mute-toggle"
    )
    (command "Audio" "Toggle microphone mute" "micmute" "KEY_MICMUTE"
      "${swayosdClient} --input-volume mute-toggle"
    )
    (command "Audio" "Increase volume" "volumeup" "KEY_VOLUMEUP"
      "${unmuteOutput}; ${swayosdClient} --output-volume +5"
    )
    (command "Audio" "Decrease volume" "volumedown" "KEY_VOLUMEDOWN"
      "${unmuteOutput}; ${swayosdClient} --output-volume -5"
    )
    (command "Display" "Increase brightness" "brightnessup" "KEY_BRIGHTNESSUP"
      "${swayosdClient} --brightness +5"
    )
    (command "Display" "Decrease brightness" "brightnessdown" "KEY_BRIGHTNESSDOWN"
      "${swayosdClient} --brightness -5"
    )
    # Show the caps lock state on release, after the press has toggled it.
    (
      (command "Keyboard" "Show Caps Lock state" "caps_lock" "KEY_CAPSLOCK"
        "${swayosdClient} --caps-lock"
      )
      // {
        option = "release_binding_caps_lock";
      }
    )
    (command "Capture" "Open capture menu" "capture_menu" "KEY_SYSRQ" "fuzzel-capture")
    (command "Capture" "Capture window" "capture_window" "<alt> KEY_SYSRQ" "fuzzel-capture window")
    (command "Capture" "Capture region" "capture_region" "<shift> KEY_SYSRQ" "fuzzel-capture region")
    (command "Capture" "Capture primary output" "capture_output" "<ctrl> <alt> KEY_SYSRQ"
      "fuzzel-capture output ${display.primaryOutput}"
    )
    (command "Menu" "Open Bluetooth menu" "bluetooth" "<ctrl> <alt> KEY_B" "fuzzel-bluetooth")
    (command "Menu" "Choose emoji" "emoji" "<ctrl> <alt> KEY_E" "fuzzel-emoji")
    (command "Menu" "Open clipboard history" "clipboard" "<ctrl> <alt> KEY_P" "fuzzel-clipboard")
    (command "Menu" "Open shell history" "history" "<ctrl> <alt> KEY_R" "fuzzel-history")
    (command "Menu" "Open session menu" "session" "<ctrl> <alt> KEY_SPACE" "fuzzel-session-menu")
    (command "Menu" "Open keyboard shortcut help" "keybindings" "<ctrl> <alt> KEY_K"
      "fuzzel-keybindings"
    )
    (command "Menu" "Open notes" "notes" "<ctrl> <alt> KEY_Z" "fuzzel-notes")
    (command "Application" "Toggle application grid" "launcher" "<super>"
      "${pkgs.procps}/bin/pkill rofi || rofi -theme ${config.xdg.configHome}/rofi/launchers/rofi-appgrid/style.rasi -show drun"
    )
    (command "Session" "Toggle notifications" "notifications" "<super> KEY_N"
      "${pkgs.swaynotificationcenter}/bin/swaync-client --toggle-panel --skip-wait"
    )
    (command "Session" "Lock screen" "lock" "<super> KEY_L" "${veilaBin} lock")
    (command "Application" "Open terminal" "terminal" "<super> KEY_T" (
      lib.getExe pkgs.xdg-terminal-exec
    ))
  ]
  ++ lib.optional host.network.wifi (
    command "Menu" "Open Wi-Fi menu" "wifi" "<ctrl> <alt> KEY_W" "fuzzel-wifi"
  )
  ++ lib.optional isHandyHost (
    command "Application" "Toggle voice transcription" "handy" "<super> KEY_V"
      "handy --toggle-transcription"
  );
  bindings =
    commands
    ++ [
      (binding "Workspaces" "Rotate to previous workspace" "cube" "rotate_left" "<ctrl> <alt> KEY_LEFT")
      (binding "Workspaces" "Rotate to next workspace" "cube" "rotate_right" "<ctrl> <alt> KEY_RIGHT")
      (binding "Windows" "Toggle overview" "expo" "toggle" "<super> KEY_HOME")
      (binding "Windows" "Snap window to left half" "grid" "slot_l" "<super> <alt> KEY_LEFT")
      (binding "Windows" "Snap window to right half" "grid" "slot_r" "<super> <alt> KEY_RIGHT")
      (binding "Windows" "Snap window to top half" "grid" "slot_t" "<super> <alt> KEY_UP")
      (binding "Windows" "Snap window to bottom half" "grid" "slot_b" "<super> <alt> KEY_DOWN")
      (binding "Session" "Toggle idle detection" "idle" "toggle" "<super> KEY_Z")
      (binding "Windows" "Switch to next window" "switcher" "next_view" "<alt> KEY_TAB")
      (binding "Windows" "Switch to previous window" "switcher" "prev_view" "<alt> <shift> KEY_TAB")
      (binding "Windows" "Toggle maximised window" "wm-actions" "toggle_maximize" "<super> KEY_UP")
    ]
    ++ map (
      n:
      binding "Workspaces" "View workspace ${toString n}" "vswitch" "binding_${toString n}"
        "<ctrl> <alt> KEY_${toString n}"
    ) (lib.range 1 8);
  cfg = config.wayland.windowManager.wayfire;
  effectiveKeys = settings: record: lib.attrByPath [ record.section record.option ] "none" settings;
  # Read final keys, but omit changed commands and disabled plugins rather
  # than advertise an action that the effective configuration cannot perform.
  active =
    settings: record:
    let
      keys = effectiveKeys settings record;
      plugins = lib.splitString " " (settings.core.plugins or "");
    in
    builtins.elem record.section plugins
    && builtins.isString keys
    && keys != ""
    && keys != "none"
    && builtins.match "(<[a-z]+> ?)*(KEY_[A-Z0-9_]+)?" keys != null
    && (
      !(record ? commandOption)
      || lib.attrByPath [ "command" record.commandOption ] null settings == record.action
    );
  keyNames = {
    "<ctrl>" = "Ctrl";
    "<alt>" = "Alt";
    "<super>" = "Super";
    "<shift>" = "Shift";
    KEY_SYSRQ = "Print";
    KEY_CAPSLOCK = "Caps Lock";
    KEY_PLAYPAUSE = "Play/Pause";
    KEY_PREVIOUS = "Previous Track";
    KEY_NEXT = "Next Track";
    KEY_MUTE = "Mute";
    KEY_MICMUTE = "Microphone Mute";
    KEY_VOLUMEUP = "Volume Up";
    KEY_VOLUMEDOWN = "Volume Down";
    KEY_BRIGHTNESSUP = "Brightness Up";
    KEY_BRIGHTNESSDOWN = "Brightness Down";
    KEY_LEFT = "Left";
    KEY_RIGHT = "Right";
    KEY_UP = "Up";
    KEY_DOWN = "Down";
    KEY_HOME = "Home";
    KEY_TAB = "Tab";
    KEY_SPACE = "Space";
  };
  entry = record: {
    inherit (record) description category;
    keys = lib.concatStringsSep "+" (
      map (key: keyNames.${key} or (lib.removePrefix "KEY_" key)) (
        lib.filter (key: key != "") (lib.splitString " " (effectiveKeys cfg.settings record))
      )
    );
    keywords = lib.optional (lib.hasPrefix "release_binding_" record.option) "release";
  };
  # Gate: just eval and Home Manager builds run these effective-binding checks.
  entries =
    assert lib.assertMsg (
      let
        record = command "Test" "Test action" "test" "KEY_A" "original";
        settings = {
          core.plugins = "command";
          command = {
            binding_test = record.keys;
            command_test = record.action;
          };
        };
        withKeys = keys: lib.recursiveUpdate settings { command.binding_test = keys; };
      in
      active settings record
      && active (withKeys "<ctrl> KEY_B") record
      && !(active (withKeys "none") record)
      && !(active (withKeys "<super> BTN_LEFT") record)
      && !(active (lib.recursiveUpdate settings { command.command_test = "replacement"; }) record)
      && !(active (settings // { core.plugins = ""; }) record)
      && !(active { core.plugins = "command"; } record)
    ) "Wayfire keyboard help must follow effective keys, commands, and plugin gates.";
    map entry (
      lib.filter (record: record.category != "Keyboard" && active cfg.settings record) bindings
    );
in
{
  config = lib.mkIf (host.desktop == "wayfire") {
    compositor.keybindingHelp.entries = lib.optionals cfg.enable entries;
    wayland.windowManager.wayfire.settings =
      lib.foldl' lib.recursiveUpdate { autostart.rofi = false; }
        (
          map (
            record:
            lib.recursiveUpdate { ${record.section}.${record.option} = record.keys; } (
              lib.optionalAttrs (record ? commandOption) {
                command.${record.commandOption} = record.action;
              }
            )
          ) bindings
        );
  };
}
