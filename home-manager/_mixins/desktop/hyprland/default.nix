{
  config,
  hostname,
  lib,
  pkgs,
  ...
}:
let
  monitors = (import ./monitors.nix { }).${hostname};
  hyprSession = pkgs.writeShellApplication {
    name = "hypr-session";
    runtimeInputs = with pkgs; [
      coreutils-full
      gnused
      obs-cmd
      playerctl
      procps
    ];
    text = ''
      set +e  # Disable errexit
      set +u  # Disable nounset
      HOSTNAME=$(hostname -s)

      function app_is_running() {
          local CLASS="$1"
          if hyprctl clients | grep "$CLASS" &>/dev/null; then
              return 0
          fi
          return 1
      }

      function block_on_app() {
          local COUNT=0
          local SLEEP=0.5
          local LIMIT=15
          local CLASS="$1"
          echo " - Ignoring $CLASS..."
          while app_is_running "$CLASS"; do
              sleep "$SLEEP"
              ((COUNT++))
              if [ "$COUNT" -ge "$LIMIT" ]; then
                  echo " - Ignored $CLASS for long enough"
                  break
              else
                  echo " - Ignored $CLASS $COUNT times..."
              fi
          done
      }

      function wait_for_app() {
          local COUNT=0
          local SLEEP=1
          local LIMIT=5
          local CLASS="$1"
          echo " - Waiting for $CLASS..."
          while ! app_is_running "$CLASS"; do
              sleep "$SLEEP"
              ((COUNT++))
              if [ "$COUNT" -ge "$LIMIT" ]; then
                  echo " - Failed to find $CLASS"
                  break
              fi
          done
      }

      function start_app() {
          local APP="$1"
          local WORKSPACE="$2"
          local CLASS="$3"
          if ! app_is_running "$CLASS"; then
              echo -n " - Starting $APP on workspace $WORKSPACE: "
              hyprctl dispatch exec "[workspace $WORKSPACE silent]" "$APP"
              if [ "$APP" == "tenacity" ]; then
                  #block_on_app "title: Tenacity is starting up..."
                  sleep 5
              fi
              wait_for_app "$CLASS"
          else
              echo " - $APP is already running"
          fi
          echo -n " - Moving $CLASS to $WORKSPACE: "
          hyprctl dispatch movetoworkspacesilent "$WORKSPACE,$CLASS"
          hyprctl dispatch movetoworkspacesilent "$WORKSPACE,$APP" &>/dev/null
          if [ "$APP" == "gitkraken" ]; then
              hyprctl dispatch movetoworkspacesilent "$WORKSPACE,GitKraken" &>/dev/null
          fi
      }

      function start_appimage() {
          local APPIMAGE="$1"
          local CLASS="$2"
          local WORKSPACE="$3"
          local SHORT_CLASS=""
          SHORT_CLASS=$(echo "$2" | cut -d':' -f2 | sed 's/ //g')
          if [ -e "$HOME/Apps/$APPIMAGE" ]; then
              if ! app_is_running "$CLASS"; then
                  disrun appimage-run "$HOME/Apps/$APPIMAGE" &>/dev/null
                  wait_for_app "$CLASS"
                  hyprctl dispatch movetoworkspacesilent "$WORKSPACE","$SHORT_CLASS"
              else
                  echo " - $APPIMAGE is already running"
              fi
          fi
      }

      function session_start() {
          start_app brave 1 "class: brave-browser"
          start_app wavebox 2 "class: wavebox"
          start_app discord 2 " - Discord"
          start_app telegram-desktop 3 "initialTitle: Telegram"
          start_app fractal 3 "class: org.gnome.Fractal"
          start_app halloy 3 "class: org.squidowl.halloy"
          start_app code 4 "initialTitle: Visual Studio Code"
          start_app "gitkraken --no-show-splash-screen" 4 "title: GitKraken Desktop"
          start_app alacritty 5 "class: Alacritty"
          start_app pods 6 "class: com.github.marhkb.Pods"
          if [ "$HOSTNAME" == "phasma" ] || [ "$HOSTNAME" == "vader" ]; then
              start_app "obs --disable-shutdown-check --collection 'VirtualCam' --profile 'VirtualCam' --scene 'VirtualCam-DetSys' --startvirtualcam" 7 "class: com.obsproject.Studio"
          fi
          firefox -CreateProfile meet-detsys
          start_app "firefox \
            -P meet-detsys \
            -no-remote \
            --new-window https://meet.google.com" 9 "title: Google Meet - Mozilla Firefox"

          start_appimage "Cider-linux-appimage-x64.AppImage" "class: Cider" 8
          start_appimage "Heynote.AppImage" "class: Heynote" 9

          if ! pidof -q trayscale; then
              disrun trayscale --gapplication-service --hide-window
          fi
          hyprctl dispatch forcerendererreload
      }

      function session_linuxmatters() {
          start_app tenacity 9 "class: tenacity"
          firefox -CreateProfile linuxmatters-stage
          start_app "firefox -P linuxmatters-stage -no-remote --new-window https://github.com/restfulmedia/linuxmatters_backstage" 9 "title: restfulmedia/linuxmatters_backstage"
          if [ "$HOSTNAME" == "phasma" ] || [ "$HOSTNAME" == "vader" ]; then
              start_app "obs --disable-shutdown-check --collection VirtualCam --profile VirtualCam --scene VirtualCam-LinuxMatters --startvirtualcam" 9 "class: com.obsproject.Studio"
          fi
          hyprctl dispatch workspace 9 &>/dev/null
          firefox -CreateProfile linuxmatters-studio
          start_app "firefox \
              -P linuxmatters-studio \
              -no-remote \
              --new-window https://talky.io/linux-matters-studio" 7 "title: Talky — Mozilla Firefox"
          start_app telegram-desktop 7 "initialTitle: Telegram"
          start_app "nautilus -w $HOME/Audio" 7 "title: Audio"
          hyprctl dispatch workspace 7 &>/dev/null
          hyprctl dispatch forcerendererreload
      }

      function session_stream_common() {
          start_app chatterino 7 "chatterino"
          start_app discord 9 " - Discord"
      }

      function session_wimpysworld() {
          firefox -CreateProfile wimpysworld-studio
          start_app "firefox \
              -P wimpysworld-studio \
              -no-remote \
              --new-window https://dashboard.twitch.tv/u/wimpysworld/stream-manager \
              --new-tab https://streamelements.com \
              --new-tab https://botrix.live" 9 "title: Twitch — Mozilla Firefox"
          start_app "obs --disable-shutdown-check --collection 'Wimpys World' --profile Dev-Local --scene Collage" 7 "class: com.obsproject.Studio"
          session_stream_common
          start_app code 10 "initialTitle: Visual Studio Code"
          start_app gitkraken 10 "title: GitKraken Desktop"
          start_app alacritty 10 "class: Alacritty"
          firefox -CreateProfile wimpysworld-stage
          start_app "firefox \
              -P wimpysworld-stage \
              -no-remote \
              --new-window https://wimpysworld.com
              --new-tab https://github.com/wimpysworld" 10 "title: Wimpy's World — Mozilla Firefox"
          hyprctl dispatch forcerendererreload
      }

      function session_8bitversus() {
          firefox -CreateProfile 8bitversus-studio
          start_app "firefox \
            -P 8bitversus-studio \
            -no-remote \
            --new-window https://dashboard.twitch.tv/u/8bitversus/stream-manager" 9 "title: Twitch — Mozilla Firefox"
          start_app "obs --disable-shutdown-check --collection 8-bit-VS --profile 8-bit-VS-Local --scene Hosts" 7 "class: com.obsproject.Studio"
          session_stream_common
          hyprctl dispatch forcerendererreload
      }

      function session_clear() {
          obs-cmd virtual-camera stop
          sleep 0.25
          hyprctl clients -j | jq -r ".[].address" | xargs -I {} hyprctl dispatch closewindow address:{}
          sleep 0.75
          hyprctl dispatch workspace 1 &>/dev/null
      }

      function session_stop() {
          playerctl --all-players pause
          pkill trayscale
          session_clear
      }

      OPT="help"
      if [ -n "$1" ]; then
          OPT="$1"
      fi

      case "$OPT" in
          8bitversus) session_8bitversus;;
          linuxmatters) session_linuxmatters;;
          wimpysworld) session_wimpysworld;;
          start) session_start;;
          clear) session_clear;;
          lock)
            pkill wlogout
            sleep 0.5
            hyprlock --immediate;;
          logout)
            session_stop
            hyprctl dispatch exit;;
          reboot)
            session_stop
            systemctl reboot;;
          shutdown)
            session_stop
            systemctl poweroff;;
          *) echo "Usage: $(basename "$0") {start|clear|logout|reboot|shutdown|8bitversus|linuxmatters|wimpysworld}";
            exit 1;;
      esac
    '';
  };
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
  home.packages = with pkgs; [
    hyprSession
    portalProdder
  ];

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
          "CTRL ALT, 0, workspace, 10"
          "$mod ALT, 0, movetoworkspace, 10"
      ];
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
          passes = 2;
          size = 6;
          ignore_opacity = true;
        };
      };
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
        "opacity 0.72, floating:1"

        # make pop-up file dialogs floating, centred, and pinned
        "float, title:(Open|Progress|Save File)"
        "center, title:(Open|Progress|Save File)"
        "pin, title:(Open|Progress|Save File)"
        "float, class:(xdg-desktop-portal-gtk)"
        "center, class:(xdg-desktop-portal-gtk)"
        "pin, class:(xdg-desktop-portal-gtk)"
        "float, class:^(code)$"
        "center, class:^(code)$"
        "pin, class:^(code)$"

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
        "size 960 640 initialTitle:(Polychromatic)"
        "size 880 1010, title:(overskride)"
        "size 886 960, title:(Trayscale)"
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
