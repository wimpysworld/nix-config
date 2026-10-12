{
  config,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  tailscale = lib.getExe config.services.tailscale.package;
  # Keep these in sync with `HOST` and `PORT` of the Herdr Web user service in
  # home-manager/_mixins/terminal/herdr.nix.
  herdrWebUiTarget = "http://127.0.0.1:7317";
  httpsPort = "8443";
in
# Tailscale Serve, not Caddy, fronts Herdr Web. Serve sets and strips the
# `Tailscale-User-Login` header that Herdr Web trusts from a loopback client.
lib.mkIf
  (
    noughtyLib.isHost [
      "skrye"
      "zannah"
    ]
    && config.services.tailscale.enable
  )
  {
    # The serve configuration persists in the tailscaled state. Each start sets
    # the same mapping again, so the unit is idempotent, and a stop removes it.
    systemd.services.herdr-web-ui-serve = {
      description = "Publish Herdr Web on the tailnet with Tailscale Serve";
      after = [
        "tailscaled.service"
        "tailscaled-autoconnect.service"
      ];
      wants = [ "tailscaled.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        Restart = "on-failure";
        RestartSec = 30;
        ExecStop = "${tailscale} serve --https=${httpsPort} off";
      };
      enableStrictShellChecks = true;
      # Serve needs the node to be logged in, so wait up to 60 seconds for it.
      # If serve still fails, systemd tries again after `RestartSec`.
      script = ''
        for _ in {1..120}; do
          if ${tailscale} status --peers=false --json \
            | ${lib.getExe pkgs.jq} -e '.BackendState == "Running"' >/dev/null 2>&1; then
            break
          fi
          sleep 0.5
        done
        exec ${tailscale} serve --bg --yes --https=${httpsPort} ${herdrWebUiTarget}
      '';
    };
  }
