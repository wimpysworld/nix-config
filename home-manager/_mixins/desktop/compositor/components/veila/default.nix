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
  veiladBin = lib.getExe' veila "veilad";
  fprintdEnabled = noughtyLib.hostHasTag "fprintd";
  passEnvironment = "WAYLAND_DISPLAY XDG_SESSION_ID XDG_SESSION_TYPE XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE SWAYSOCK NIRI_SOCKET";
in
lib.mkIf (host.is.linux && host.is.workstation) {
  # Veila is a Wayland-native screen locker that replaces hyprlock. The package
  # and the `veila` PAM service are provided by the NixOS module; this mixin
  # writes the user config, runs the daemon and idle monitor, and binds locking.
  xdg.configFile."veila/config.toml".text = ''
    # The bundled "catppuccin" preset is Catppuccin Mocha out of the box, so the
    # config only sets behaviour and the few personal keys; the main config
    # always wins over the theme.
    theme = "catppuccin"

    [lock]
    hide_cursor = true
    # Submit Enter-on-empty to PAM so the fingerprint flow can proceed.
    allow_empty_password = true
    # Power displays off while locked (replaces hypridle's dpms listener).
    screen_off_seconds = 305
    # suspend_seconds left unset: suspend stays with logind, not Veila.

    [fingerprint]
    # Native fprintd over D-Bus; only on hosts with the fprintd tag.
    enabled = ${lib.boolToString fprintdEnabled}

    [now_playing]
    # Show only Sidra's MPRIS player.
    include_players = ["sidra"]

    [visuals.outputs]
    # UI on one output; others get secure curtains (global default is "all").
    ui_mode = "single"
    # Pin the prompt to the primary output; falls back to focused if unset.
    ui_output = "${display.primaryOutput}"

    [visuals.clock]
    format = "24h"
  '';

  # Tune the packaged idle monitor without editing the unit file.
  xdg.configFile."veila/idle.env".text = ''
    VEILA_IDLE_LOCK_AFTER=300
    VEILA_IDLE_SLEEP_FLAG=--lock-before-sleep
  '';

  # Run the locker daemon and idle monitor as user services. The package ships
  # these as templates under share/veila/systemd with Debian paths, so define
  # them here against the Nix store binaries.
  systemd.user.services = {
    veilad = {
      Unit = {
        Description = "Veila screen locker daemon";
        After = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
      };
      Service = {
        Type = "simple";
        ExecStart = veiladBin;
        Restart = "on-failure";
        RestartSec = 2;
        PassEnvironment = passEnvironment;
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
    veila-idle = {
      Unit = {
        Description = "Veila idle and sleep lock monitor";
        After = [
          "graphical-session.target"
          "veilad.service"
        ];
        PartOf = [ "graphical-session.target" ];
      };
      Service = {
        Type = "simple";
        Environment = [
          "VEILA_IDLE_LOCK_AFTER=300"
          "VEILA_IDLE_SLEEP_FLAG=--lock-before-sleep"
        ];
        EnvironmentFile = "-%h/.config/veila/idle.env";
        ExecStart = "${veilaBin} idle --lock-after=\${VEILA_IDLE_LOCK_AFTER} $VEILA_IDLE_SLEEP_FLAG";
        Restart = "on-failure";
        RestartSec = 2;
        PassEnvironment = passEnvironment;
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
  };

  wayland.windowManager.hyprland = {
    settings = {
      bind = [
        "$mod, L, exec, ${veilaBin} lock"
        "CTRL ALT, L, exec, ${veilaBin} lock"
      ];
    };
  };
}
