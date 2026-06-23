{
  config,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  username = config.noughty.user.name;
  sojuAdminSocket = "/run/soju/admin";
  tailnetHost = "${host.name}.${config.noughty.network.tailNet}";
  sojuPort = 7667;
  sojuSopsFile = ../../../../secrets + "/halloy.yaml";
  sojuBootstrap = pkgs.writeShellApplication {
    name = "soju-bootstrap";
    runtimeInputs = [
      config.services.soju.package
      pkgs.coreutils
      pkgs.gnugrep
    ];
    text = ''
      : "''${SOJU_PASSWORD_FILE:?}"
      : "''${LIBERA_PASSWORD_FILE:?}"
      : "''${OFTC_PASSWORD_FILE:?}"

      readSecret() {
        local secretFile="$1"

        if [ ! -r "$secretFile" ]; then
          printf 'Required secret file is unavailable: %s\n' "$secretFile" >&2
          exit 1
        fi

        local secret
        secret="$(<"$secretFile")"

        if [ -z "$secret" ]; then
          printf 'Required secret file is empty: %s\n' "$secretFile" >&2
          exit 1
        fi

        printf '%s' "$secret"
      }

      sojuPassword="$(readSecret "$SOJU_PASSWORD_FILE")"
      liberaPassword="$(readSecret "$LIBERA_PASSWORD_FILE")"
      oftcPassword="$(readSecret "$OFTC_PASSWORD_FILE")"

      waitForSojuAdmin() {
        local attempt=1

        while [ "$attempt" -le 30 ]; do
          if [ -S "${sojuAdminSocket}" ]; then
            return 0
          fi

          sleep 1
          attempt=$((attempt + 1))
        done

        printf 'Soju admin socket was unavailable after waiting.\n' >&2
        exit 1
      }

      waitForSojuAdmin

      commandFailedBecauseExisting() {
        local errorFile="$1"

        grep -Eiq 'already|duplicate|exist|taken' "$errorFile"
      }

      ensureUser() {
        local createError
        createError="$(mktemp)"

        local createStatus

        if sojuctl -config "${config.services.soju.configFile}" user create \
          -username "${username}" \
          -password "$sojuPassword" \
          -admin=true \
          -nick "Wimpy" 2>"$createError"; then
          rm -f "$createError"
          return 0
        else
          createStatus=$?
        fi

        if commandFailedBecauseExisting "$createError"; then
          rm -f "$createError"
          sojuctl -config "${config.services.soju.configFile}" user update "${username}" \
            -password "$sojuPassword" \
            -admin=true \
            -enabled=true
          return 0
        fi

        cat "$createError" >&2
        rm -f "$createError"
        return "$createStatus"
      }

      ensureUser

      ensureNetwork() {
        local networkName="$1"
        local address="$2"
        local nick="$3"
        local upstreamUsername="$4"
        local createError
        createError="$(mktemp)"

        local createStatus

        if sojuctl -config "${config.services.soju.configFile}" user run "${username}" network create \
          -addr "$address" \
          -name "$networkName" \
          -username "$upstreamUsername" \
          -nick "$nick" \
          -enabled=true 2>"$createError"; then
          rm -f "$createError"
          return 0
        else
          createStatus=$?
        fi

        if commandFailedBecauseExisting "$createError"; then
          rm -f "$createError"
          sojuctl -config "${config.services.soju.configFile}" user run "${username}" network update "$networkName" \
            -addr "$address" \
            -username "$upstreamUsername" \
            -nick "$nick" \
            -enabled=true
          return 0
        fi

        cat "$createError" >&2
        rm -f "$createError"
        return "$createStatus"
      }

      ensureNetwork "libera" "irc.libera.chat" "Wimpy" "flexiondotorg/irc.libera.chat@nixos"
      sojuctl -config "${config.services.soju.configFile}" user run "${username}" sasl set-plain \
        -network "libera" \
        "Wimpy" \
        "$liberaPassword"

      ensureNetwork "oftc" "irc.oftc.net" "Wimpress" "flexiondotorg/irc.oftc.net@nixos"
      sojuctl -config "${config.services.soju.configFile}" user run "${username}" sasl set-plain \
        -network "oftc" \
        "Wimpress" \
        "$oftcPassword"
    '';
  };
in
lib.mkIf (noughtyLib.hostHasTag "irc-bouncer") {
  environment.systemPackages = [
    sojuBootstrap
  ];

  sops.secrets = {
    SOJU_PASSWORD = {
      sopsFile = sojuSopsFile;
      owner = "root";
      group = "root";
      mode = "0400";
    };

    LIBERA_PASSWORD = {
      sopsFile = sojuSopsFile;
      owner = "root";
      group = "root";
      mode = "0400";
    };

    OFTC_PASSWORD = {
      sopsFile = sojuSopsFile;
      owner = "root";
      group = "root";
      mode = "0400";
    };
  };

  services = {
    caddy.virtualHosts."${tailnetHost}".extraConfig =
      lib.mkIf (config.services.caddy.enable && config.services.tailscale.enable)
        ''
          @sojuSocket path /socket
          reverse_proxy @sojuSocket localhost:${toString sojuPort}

          @sojuUploads path /uploads /uploads/*
          reverse_proxy @sojuUploads localhost:${toString sojuPort}
        '';

    soju = {
      enable = true;
      hostName = lib.mkDefault tailnetHost;
      listen = lib.mkDefault [
        "http://localhost:${toString sojuPort}"
        "irc+insecure://${tailnetHost}:6667"
      ];
      adminSocket.enable = lib.mkDefault true;
      enableMessageLogging = lib.mkDefault false;
      httpOrigins = lib.mkDefault [ "https://${tailnetHost}" ];
      acceptProxyIP = lib.mkDefault [ "localhost" ];
      extraConfig = ''
        message-store db
      '';
    };
  };

  systemd.services.soju-bootstrap = {
    description = "Bootstrap Soju users and IRC networks";
    wantedBy = [ "multi-user.target" ];
    after = [ "soju.service" ];
    requires = [ "soju.service" ];
    environment = {
      SOJU_PASSWORD_FILE = config.sops.secrets.SOJU_PASSWORD.path;
      LIBERA_PASSWORD_FILE = config.sops.secrets.LIBERA_PASSWORD.path;
      OFTC_PASSWORD_FILE = config.sops.secrets.OFTC_PASSWORD.path;
    };
    serviceConfig = {
      Type = "oneshot";
      User = "root";
      Group = "root";
      ExecStart = lib.getExe sojuBootstrap;
    };
  };
}
