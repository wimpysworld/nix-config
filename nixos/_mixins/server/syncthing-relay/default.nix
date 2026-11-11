{
  config,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  network = import ../../../../lib/syncthing-network.nix;
in
lib.mkIf (noughtyLib.isHost [ "malak" ]) {
  services.syncthing.relay = {
    enable = true;
    pools = [ ];
    port = 22067;
    statusListenAddress = "127.0.0.1";
    providedBy = "Wimpy's World";
  };

  networking.firewall.allowedTCPPorts = [ config.services.syncthing.relay.port ];

  sops.secrets = lib.genAttrs [ "relay_cert" "relay_key" ] (_: {
    sopsFile = ../../../../secrets/syncthing-relay.yaml;
    mode = "0400";
  });

  systemd.services.syncthing-relay = {
    restartTriggers = [ ../../../../secrets/syncthing-relay.yaml ];
    serviceConfig = {
      UMask = "0077";
      StateDirectoryMode = "0700";
      LoadCredential = [
        "cert.pem:${config.sops.secrets.relay_cert.path}"
        "key.pem:${config.sops.secrets.relay_key.path}"
      ];
    };
    preStart = ''
      if [ -e "$STATE_DIRECTORY/cert.pem" ] || [ -e "$STATE_DIRECTORY/key.pem" ]; then
        test -s "$STATE_DIRECTORY/cert.pem"
        test -s "$STATE_DIRECTORY/key.pem"
      else
        install -m 0600 "$CREDENTIALS_DIRECTORY/key.pem" "$STATE_DIRECTORY/key.pem"
        install -m 0600 "$CREDENTIALS_DIRECTORY/cert.pem" "$STATE_DIRECTORY/cert.pem"
      fi
      relay_id="$(${lib.getExe pkgs.syncthing} device-id --home "$STATE_DIRECTORY")"
      if [ "$relay_id" != "${network.relayId}" ]; then
        echo "The existing relay identity does not match the configured client pin." >&2
        exit 1
      fi
    '';
  };
}
