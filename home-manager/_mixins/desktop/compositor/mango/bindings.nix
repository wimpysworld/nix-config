{
  config,
  inputs,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  inherit (host) display;
  veila = inputs.veila.packages.${pkgs.stdenv.hostPlatform.system}.default;
  veilaBin = lib.getExe' veila "veila";
  handyBin = lib.getExe pkgs.handy;
  avizoBin = "${pkgs.avizo}/bin";
  playerctlBin = lib.getExe pkgs.playerctl;

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
        "CTRL+ALT,${tag},view,${tag}${sync}"
        "SUPER+ALT,${tag},tag,${tag}${sync}"
      ]
    else
      [
        "CTRL+ALT,${tag},viewcrossmon,${tag},^${output}$"
        "SUPER+ALT,${tag},tagcrossmon,${tag},^${output}$"
      ];
  directions = [
    "Left"
    "Right"
    "Up"
    "Down"
  ];
in
{
  config = lib.mkIf (host.desktop == "mango") {
    wayland.windowManager.mango = {
      settings = {
        bind = [
          "SUPER,q,killclient"
          # The overview commits the focused window when ALT is released.
          "ALT,Tab,overcircle,current_next"
          "ALT+SHIFT,Tab,overcircle,current_prev"
        ]
        ++ map (d: "ALT,${d},focusdir,${lib.toLower d}") directions
        ++ map (d: "SUPER+ALT,${d},exchange_client,${lib.toLower d}") directions
        ++ [
          "SUPER,Up,togglemaximizescreen"
          "SUPER,Down,togglefloating"
          "CTRL+ALT,Left,viewtoleft${sync}"
          "CTRL+ALT,Right,viewtoright${sync}"
        ]
        ++ lib.concatMap mkTagBindings (lib.range 1 8)
        ++ [
          "SUPER,Home,toggleoverview"
          "SUPER,j,togglejump"
          "SUPER,r,setkeymode,resize"
          "SUPER,e,spawn,${pkgs.nautilus}/bin/nautilus --new-window"
          "SUPER,t,spawn,${lib.getExe pkgs.xdg-terminal-exec}"
        ]
        # Bind Pause by keycode (xkb 127 = evdev KEY_PAUSE 119 + 8).
        ++ lib.optionals (host.is.linux && host.is.workstation && noughtyLib.hostHasTag "handy") (
          [ "SUPER,v,spawn,${handyBin} --toggle-transcription" ]
          ++ lib.optional (!host.is.laptop) "NONE,code:127,spawn,${handyBin} --toggle-transcription"
        )
        ++ [
          "SUPER,l,spawn,${veilaBin} lock"
          "CTRL+ALT,l,spawn,${veilaBin} lock"
          "CTRL+ALT,n,spawn,${pkgs.swaynotificationcenter}/bin/swaync-client --toggle-panel --skip-wait"
          "CTRL+ALT,space,spawn,fuzzel-session-menu"
          "CTRL+ALT,e,spawn,fuzzel-emoji"
          "CTRL+ALT,p,spawn,fuzzel-clipboard"
          "CTRL+ALT,r,spawn,fuzzel-history"
          "CTRL+ALT,z,spawn,fuzzel-notes"
          "NONE,Print,spawn,fuzzel-capture"
          "ALT,Print,spawn,fuzzel-capture window"
          "SHIFT,Print,spawn,fuzzel-capture region"
          "CTRL+ALT,Print,spawn,fuzzel-capture output ${display.primaryOutput}"
        ];
        # Work while an input inhibitor is active. Mango repeats every held
        # binding, so volume and brightness repeat while the key is held.
        bindl = [
          "NONE,XF86AudioPlay,spawn,${playerctlBin} play-pause"
          "NONE,XF86AudioPrev,spawn,${playerctlBin} previous"
          "NONE,XF86AudioNext,spawn,${playerctlBin} next"
          "NONE,XF86AudioMute,spawn,${avizoBin}/volumectl toggle-mute"
          "NONE,XF86AudioMicMute,spawn,${avizoBin}/volumectl -m toggle-mute"
          "NONE,XF86AudioRaiseVolume,spawn,${avizoBin}/volumectl -u up"
          "NONE,XF86AudioLowerVolume,spawn,${avizoBin}/volumectl -u down"
          "NONE,XF86MonBrightnessUp,spawn,${avizoBin}/lightctl up"
          "NONE,XF86MonBrightnessDown,spawn,${avizoBin}/lightctl down"
        ];
        # A tap of SUPER on its own toggles the application grid.
        bindr = [
          "SUPER,Super_L,spawn_shell,${pkgs.procps}/bin/pkill rofi || rofi -theme ${config.xdg.configHome}/rofi/launchers/rofi-appgrid/style.rasi -show drun"
        ];
        mousebind = [
          "SUPER,btn_left,moveresize,curmove"
          "SUPER,btn_right,moveresize,curresize"
        ];
        gesturebind = [
          "none,left,3,viewtoright${sync}"
          "none,right,3,viewtoleft${sync}"
        ];
      };
      keymodes.resize = [
        "bind=NONE,Left,resizewin,-40,+0"
        "bind=NONE,Right,resizewin,+40,+0"
        "bind=NONE,Up,resizewin,+0,-40"
        "bind=NONE,Down,resizewin,+0,+40"
        "bind=SHIFT,Left,movewin,-40,+0"
        "bind=SHIFT,Right,movewin,+40,+0"
        "bind=SHIFT,Up,movewin,+0,-40"
        "bind=SHIFT,Down,movewin,+0,+40"
        "bind=NONE,Escape,setkeymode,default"
        "bind=NONE,Return,setkeymode,default"
      ];
    };
  };
}
