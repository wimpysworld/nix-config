{
  config,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  host = config.noughty.host;
  primaryOutput = host.display.primaryOutput;
  # sops-nix renders the wayvnc config with the password at activation time.
  wayvncConfigPath = "${config.xdg.configHome}/sops-nix/secrets/wayvnc-config";
in
lib.mkIf
  (
    noughtyLib.hostHasTag "wayvnc"
    && (config.wayland.windowManager.hyprland.enable || config.wayland.windowManager.wayfire.enable)
  )
  {
    sops.secrets.wayvnc-password = {
      sopsFile = ../../../../secrets/wayvnc.yaml;
      key = "wayvnc_password";
    };

    # The sops template renders the full wayvnc config with the VNC password
    # injected at activation time. The --config CLI flag points wayvnc here
    # instead of the HM-generated ~/.config/wayvnc/config in the Nix store.
    #
    # Authentication uses VeNCrypt Plain (type 256): unencrypted username and
    # password over the VNC protocol. This is safe because all traffic runs
    # over Tailscale's WireGuard tunnel. relax_encryption=true is required
    # to allow VeNCrypt Plain without TLS or RSA credentials.
    sops.templates."wayvnc-config" = {
      content = ''
        address=127.0.0.1
        port=5900
        enable_auth=true
        relax_encryption=true
        username=${config.noughty.user.name}
        password=${config.sops.placeholder.wayvnc-password}
      '';
      path = wayvncConfigPath;
    };

    services.wayvnc = {
      enable = true;
      autoStart = true;
      # settings populates ~/.config/wayvnc/config with non-secret values.
      # At runtime, --config overrides this with the sops-rendered template
      # that includes the VNC password. The settings-generated file is
      # superseded but satisfies the HM module requirement.
      settings = {
        address = "127.0.0.1";
        port = 5900;
        enable_auth = true;
        relax_encryption = true;
        username = config.noughty.user.name;
      };
    };

    # Override ExecStart to pass CLI flags not exposed by the HM module.
    #
    # The HM module sets ExecStart to just the wayvnc binary with no arguments.
    # CLI flags cannot be set via settings - they require this override:
    #   --config           Sops-rendered config with VNC password (not Nix store)
    #   --websocket        Speaks WebSocket natively so noVNC connects directly
    #                      via Caddy reverse_proxy without a WS-to-TCP bridge
    #   --render-cursor    Composites cursor into framebuffer for reliable visibility
    #   --max-fps=30       Reasonable frame rate for remote desktop over Tailscale
    #   --output           Pins to the primary display so the lock screen and
    #                      application launchers are accessible remotely
    systemd.user.services.wayvnc = {
      Unit = {
        After = [ "sops-nix.service" ];
        Wants = [ "sops-nix.service" ];
      };
      Service.ExecStart = lib.mkForce (
        "${pkgs.wayvnc}/bin/wayvnc"
        + " --config ${wayvncConfigPath}"
        + " --websocket"
        + " --render-cursor"
        + " --max-fps=30"
        + lib.optionalString (primaryOutput != "") " --output=${primaryOutput}"
      );
    };
  }
