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
  inherit (pkgs) veila;
  veilaBin = lib.getExe' veila "veila";
  swayosdClient = lib.getExe' pkgs.swayosd "swayosd-client";
  # SwayOSD does not unmute on a volume change, so unmute the output first.
  unmuteOutput = "${lib.getExe' pkgs.wireplumber "wpctl"} set-mute @DEFAULT_AUDIO_SINK@ 0";
  playerctlBin = lib.getExe pkgs.playerctl;

  binding = category: description: native: { inherit category description native; };
  tags = import ./tags.nix { inherit host; };
  # A trailing 1 is the Mango synctag argument, which views the tag on every monitor.
  sync = lib.optionalString tags.synced ",1";
  mkTagBindings =
    n:
    let
      tag = toString n;
      output = tags.outputForTag n;
    in
    if output == null then
      [
        (binding "Workspaces" "View workspace ${tag}" "CTRL+ALT,${tag},view,${tag}${sync}")
        (binding "Workspaces" "Move window to workspace ${tag}" "SUPER+ALT,${tag},tag,${tag}${sync}")
      ]
    else
      [
        (binding "Workspaces" "View workspace ${tag} on ${output}"
          "CTRL+ALT,${tag},viewcrossmon,${tag},^${output}$"
        )
        (binding "Workspaces" "Move window to workspace ${tag} on ${output}"
          "SUPER+ALT,${tag},tagcrossmon,${tag},^${output}$"
        )
      ];
  directions = [
    "Left"
    "Right"
    "Up"
    "Down"
  ];
  bindings = {
    bind = [
      (
        (binding "Windows" "Close window" "SUPER,q,killclient")
        // {
          keywords = [
            "quit"
            "exit"
          ];
        }
      )
      # The overview commits the focused window when ALT is released.
      (binding "Windows" "Cycle to next window in overview" "ALT,Tab,overcircle,current_next")
      (binding "Windows" "Cycle to prev window in overview" "ALT+SHIFT,Tab,overcircle,current_prev")
    ]
    ++ map (
      d: binding "Windows" "Focus window ${lib.toLower d}" "ALT,${d},focusdir,${lib.toLower d}"
    ) directions
    ++ map (
      d:
      binding "Windows" "Exchange window ${lib.toLower d}"
        "SUPER+ALT,${d},exchange_client,${lib.toLower d}"
    ) directions
    ++ [
      (binding "Windows" "Toggle maximised window" "SUPER,Up,togglemaximizescreen")
      (binding "Windows" "Toggle floating window" "SUPER,Down,togglefloating")
      (binding "Workspaces" "View previous workspace" "CTRL+ALT,Left,viewtoleft${sync}")
      (binding "Workspaces" "View next workspace" "CTRL+ALT,Right,viewtoright${sync}")
    ]
    ++ lib.concatMap mkTagBindings (lib.range 1 8)
    ++ [
      (binding "Windows" "Toggle overview" "SUPER,Home,toggleoverview")
      (binding "Windows" "Toggle window jump" "SUPER,j,togglejump")
      (binding "Windows" "Enter resize mode" "SUPER,r,setkeymode,resize")
      # Start Nautilus through PATH, so that the Home profile wrapper sets
      # its extension directory.
      (binding "Application" "Open file manager" "SUPER,e,spawn,nautilus --new-window")
      (binding "Application" "Open terminal" "SUPER,t,spawn,${lib.getExe pkgs.xdg-terminal-exec}")
    ]
    ++ lib.optional (host.is.linux && host.is.workstation && noughtyLib.hostHasTag "handy") (
      binding "Application" "Toggle voice transcription" "SUPER,v,spawn,handy --toggle-transcription"
    )
    ++ [
      (binding "Session" "Lock screen" "SUPER,l,spawn,${veilaBin} lock")
      (binding "Session" "Toggle notifications"
        "SUPER,n,spawn,${pkgs.swaynotificationcenter}/bin/swaync-client --toggle-panel --skip-wait"
      )
      (binding "Menu" "Open session menu" "CTRL+ALT,space,spawn,fuzzel-session-menu")
      (binding "Menu" "Open keyboard shortcut help" "CTRL+ALT,k,spawn,fuzzel-keybindings")
      (binding "Menu" "Choose emoji" "CTRL+ALT,e,spawn,fuzzel-emoji")
      (binding "Menu" "Open clipboard history" "CTRL+ALT,p,spawn,fuzzel-clipboard")
      (binding "Menu" "Open shell history" "CTRL+ALT,r,spawn,fuzzel-history")
      (binding "Menu" "Open notes" "CTRL+ALT,z,spawn,fuzzel-notes")
      (binding "Capture" "Open capture menu" "NONE,Print,spawn,fuzzel-capture")
      (binding "Capture" "Capture window" "ALT,Print,spawn,fuzzel-capture window")
      (binding "Capture" "Capture region" "SHIFT,Print,spawn,fuzzel-capture region")
      (binding "Capture" "Capture primary output"
        "CTRL+ALT,Print,spawn,fuzzel-capture output ${display.primaryOutput}"
      )
    ];
    # Work while an input inhibitor is active. Mango repeats every held
    # binding, so volume and brightness repeat while the key is held.
    bindl = [
      (binding "Media" "Play or pause media" "NONE,XF86AudioPlay,spawn,${playerctlBin} play-pause")
      (binding "Media" "Previous track" "NONE,XF86AudioPrev,spawn,${playerctlBin} previous")
      (binding "Media" "Next track" "NONE,XF86AudioNext,spawn,${playerctlBin} next")
      (binding "Audio" "Toggle output mute"
        "NONE,XF86AudioMute,spawn,${swayosdClient} --output-volume mute-toggle"
      )
      (binding "Audio" "Toggle microphone mute"
        "NONE,XF86AudioMicMute,spawn,${swayosdClient} --input-volume mute-toggle"
      )
      (binding "Audio" "Increase volume"
        "NONE,XF86AudioRaiseVolume,spawn_shell,${unmuteOutput}; ${swayosdClient} --output-volume +5"
      )
      (binding "Audio" "Decrease volume"
        "NONE,XF86AudioLowerVolume,spawn_shell,${unmuteOutput}; ${swayosdClient} --output-volume -5"
      )
      (binding "Display" "Increase brightness"
        "NONE,XF86MonBrightnessUp,spawn,${swayosdClient} --brightness +5"
      )
      (binding "Display" "Decrease brightness"
        "NONE,XF86MonBrightnessDown,spawn,${swayosdClient} --brightness -5"
      )
    ];
    # Show the caps lock state on release, after the press has toggled it.
    # The p flag passes the release to the client, and Mango ignores the
    # caps lock modifier when it matches a binding.
    bindrp = [
      (binding "Keyboard" "Show Caps Lock state" "NONE,Caps_Lock,spawn,${swayosdClient} --caps-lock")
    ];
    # A tap of SUPER on its own toggles the application grid.
    bindr = [
      (binding "Application" "Toggle application grid"
        "SUPER,Super_L,spawn_shell,${pkgs.procps}/bin/pkill rofi || rofi -theme ${config.xdg.configHome}/rofi/launchers/rofi-appgrid/style.rasi -show drun"
      )
    ];
  };
  resizeBindings = [
    (binding "Resize Windows" "Resize window left" "NONE,Left,resizewin,-40,+0")
    (binding "Resize Windows" "Resize window right" "NONE,Right,resizewin,+40,+0")
    (binding "Resize Windows" "Resize window up" "NONE,Up,resizewin,+0,-40")
    (binding "Resize Windows" "Resize window down" "NONE,Down,resizewin,+0,+40")
    (binding "Resize Windows" "Move window left" "SHIFT,Left,movewin,-40,+0")
    (binding "Resize Windows" "Move window right" "SHIFT,Right,movewin,+40,+0")
    (binding "Resize Windows" "Move window up" "SHIFT,Up,movewin,+0,-40")
    (binding "Resize Windows" "Move window down" "SHIFT,Down,movewin,+0,+40")
    (binding "Resize Windows" "Leave resize mode" "NONE,Escape,setkeymode,default")
    (binding "Resize Windows" "Leave resize mode" "NONE,Return,setkeymode,default")
  ];
  cfg = config.wayland.windowManager.mango;
  chord = native: lib.take 2 (lib.splitString "," (builtins.unsafeDiscardStringContext native));
  keyNames = {
    CTRL = "Ctrl";
    ALT = "Alt";
    SUPER = "Super";
    SHIFT = "Shift";
    Super_L = "Super";
    space = "Space";
    Return = "Enter";
    Caps_Lock = "Caps Lock";
    XF86AudioPlay = "Play/Pause";
    XF86AudioPrev = "Previous Track";
    XF86AudioNext = "Next Track";
    XF86AudioMute = "Mute";
    XF86AudioMicMute = "Microphone Mute";
    XF86AudioRaiseVolume = "Volume Up";
    XF86AudioLowerVolume = "Volume Down";
    XF86MonBrightnessUp = "Brightness Up";
    XF86MonBrightnessDown = "Brightness Down";
  };
  renderKeys =
    native:
    lib.concatStringsSep "+" (
      lib.unique (
        map (key: keyNames.${key} or (if builtins.stringLength key == 1 then lib.toUpper key else key)) (
          lib.filter (key: key != "NONE") (lib.concatMap (lib.splitString "+") (chord native))
        )
      )
    );
  # Filter against effective settings so that removed or replaced bindings
  # cannot leave stale help. Ambiguous chords are not advertised.
  active =
    natives: record:
    lib.filter (native: chord native == chord record.native) natives == [ record.native ];
  effectiveBindings =
    kind:
    lib.concatMap lib.toList (
      lib.attrValues (
        lib.filterAttrs (
          name: _: lib.hasPrefix "bind" name && lib.hasInfix "r" name == lib.hasInfix "r" kind
        ) cfg.settings
      )
    );
  entry = keywords: record: {
    inherit (record) description category;
    keys = renderKeys record.native;
    keywords = keywords ++ (record.keywords or [ ]);
  };
  # Gate: direct catalogue evaluation and Home Manager builds run these checks.
  # Evaluating only home.username does not force the catalogue.
  entries =
    assert lib.assertMsg (
      let
        record.native = "NONE,a,spawn,original";
        replacement = "NONE,a,spawn,replacement";
      in
      active [ record.native ] record
      && !(active [ ] record)
      && !(active [ replacement ] record)
      && !(active [ record.native replacement ] record)
      && active [ record.native "NONE,b,spawn,other" ] record
    ) "Mango keyboard help must omit removed, replaced, and ambiguous bindings.";
    lib.concatLists (
      lib.mapAttrsToList (
        kind: records:
        map
          (entry (
            [ (if lib.hasInfix "r" kind then "release" else "repeat") ]
            ++ lib.optional (kind == "bindl") "input inhibitor"
            ++ lib.optional (kind == "bindrp") "passthrough"
          ))
          (
            lib.filter (
              record:
              record.category != "Keyboard"
              && builtins.elem record.native (lib.toList (cfg.settings.${kind} or [ ]))
              && active (effectiveBindings kind) record
            ) records
          )
      ) bindings
    )
    ++ map (entry [ "resize mode" ]) (
      lib.filter (active (map (lib.removePrefix "bind=") (cfg.keymodes.resize or [ ]))) resizeBindings
    );
in
{
  config = lib.mkIf (host.desktop == "mango") {
    compositor.keybindingHelp.entries = lib.optionals cfg.enable entries;
    wayland.windowManager.mango = {
      settings = lib.mapAttrs (_: map (record: record.native)) bindings // {
        mousebind = [
          "SUPER,btn_left,moveresize,curmove"
          "SUPER,btn_right,moveresize,curresize"
        ];
        gesturebind = [
          "none,left,3,viewtoright${sync}"
          "none,right,3,viewtoleft${sync}"
        ];
      };
      keymodes.resize = map (record: "bind=${record.native}") resizeBindings;
    };
  };
}
