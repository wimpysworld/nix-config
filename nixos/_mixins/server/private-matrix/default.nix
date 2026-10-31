{
  config,
  lib,
  noughtyLib,
  ...
}:
let
  cfg = config.services.privateMatrix;
  domain = "matrix.wimpys.world";
  octet = "(0|[1-9][0-9]?|1[0-9][0-9]|2[0-4][0-9]|25[0-5])";
  tailnetAddress = "100\\.(6[4-9]|[7-9][0-9]|1[01][0-9]|12[0-7])\\.${octet}\\.${octet}";
in
{
  options.services.privateMatrix = {
    enable = lib.mkEnableOption "the private Matrix server on Malak";
    listenAddresses = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Literal Tailnet IPv4 addresses on Malak for the HTTPS listener on port 8443.";
    };
    acmeEmail = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Explicit contact address for the Matrix certificate. ACME terms require separate acceptance.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = noughtyLib.isHost [ "malak" ];
        message = "services.privateMatrix is restricted to Malak.";
      }
      {
        assertion = config.services.tailscale.enable;
        message = "services.privateMatrix requires Tailscale.";
      }
      {
        assertion =
          cfg.listenAddresses != [ ]
          && lib.all (address: builtins.match tailnetAddress address != null) cfg.listenAddresses;
        message = "services.privateMatrix.listenAddresses requires literal IPv4 addresses within 100.64.0.0/10.";
      }
      {
        assertion = cfg.acmeEmail != null && builtins.match ".*[^[:space:]].*" cfg.acmeEmail != null;
        message = "services.privateMatrix.acmeEmail requires an explicit certificate contact address.";
      }
      {
        assertion = config.security.acme.acceptTerms;
        message = "services.privateMatrix requires separate, explicit acceptance through security.acme.acceptTerms.";
      }
    ];

    services.matrix-tuwunel = {
      enable = true;
      settings.global = {
        server_name = domain;
        address = [ "127.0.0.1" ];
        port = [ 6167 ];
        allow_registration = false;
        allow_federation = false;
        federate_created_rooms = false;
        allow_encryption = false;
        encryption_enabled_by_default_for_room_type = "none";
        allow_public_room_directory_over_federation = false;
        allow_public_room_directory_without_auth = false;
        require_auth_for_profile_requests = true;
        trusted_servers = [ ];
      };
    };

    services.caddy = {
      enable = true;
      virtualHosts = {
        "https://${domain}:8443" = {
          inherit (cfg) listenAddresses;
          useACMEHost = domain;
          extraConfig = ''
            @tailnet remote_ip 100.64.0.0/10 fd7a:115c:a1e0::/48
            handle @tailnet {
              reverse_proxy 127.0.0.1:6167
            }
            handle {
              respond 403
            }
          '';
        };
        "http://${domain}".extraConfig = ''
          respond 404
        '';
      };
    };

    systemd.services.caddy = {
      after = [ "tailscaled-autoconnect.service" ];
      wants = [ "tailscaled-autoconnect.service" ];
    };

    security.acme.certs.${domain} = {
      email = cfg.acmeEmail;
      dnsProvider = "cloudflare";
      credentialFiles.CLOUDFLARE_DNS_API_TOKEN_FILE =
        config.sops.secrets.CLOUDFLARE_DNS_API_TOKEN_MATRIX.path;
    };

    sops.secrets.CLOUDFLARE_DNS_API_TOKEN_MATRIX = {
      sopsFile = ../../../../secrets/cloudflare.yaml;
      owner = "root";
      group = "root";
      mode = "0600";
    };
  };
}
