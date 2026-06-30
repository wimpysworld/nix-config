{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;

  mpvWrapper = pkgs.writeShellApplication {
    name = "mpv";
    text = ''
      if [ -n "''${KITTY_WINDOW_ID:-}" ] || [ "''${TERM:-}" = "xterm-kitty" ]; then
        exec ${lib.getExe pkgs.mpv} --really-quiet --vo=kitty "$@"
      fi

      case "''${TERM_PROGRAM:-}:''${TERM:-}" in
        WezTerm:* | *:contour* | *:foot | *:foot-extra | *:mlterm* | *:rio* | *:*sixel*)
          exec ${lib.getExe pkgs.mpv} --really-quiet --vo=sixel "$@"
          ;;
      esac

      if [ -z "''${DISPLAY:-}" ] && [ -z "''${WAYLAND_DISPLAY:-}" ]; then
        has_local_video=false
        for video_device in /dev/fb[0-9]* /dev/dri/card[0-9]*; do
          if [ -e "$video_device" ]; then
            has_local_video=true
            break
          fi
        done

        if [ "$has_local_video" = false ]; then
          exec ${lib.getExe pkgs.mpv} --really-quiet --vo=tct --vo-tct-algo=half-blocks "$@"
        fi
      fi

      exec ${lib.getExe pkgs.mpv} "$@"
    '';
  };
in
lib.mkIf (host.is.linux && host.is.workstation) {
  home.packages = [ mpvWrapper ];
}
