{
  config,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  cfg = config.services.privateMatrix;
  domain = "matrix.wimpys.world";
  registrationSecret = "MATRIX_REGISTRATION_SHARED_SECRET";
  tuwunelUnit = config.systemd.services.tuwunel.name;
  mucssStylesheet = pkgs.fetchurl {
    name = "mu-1.4.9.min.css";
    url = "https://raw.githubusercontent.com/Digicreon/muCSS/f42cabdda91353d782bca0ed78d33e2a62396b88/dist/mu.css";
    hash = "sha256-BHE4dLRMnDvt+YyBmN1dHEpHWpR1JW641E+6NyJU0iY=";
  };
  landingSite = pkgs.linkFarm "private-matrix-landing" {
    "index.html" = ./index.html;
    "mu.min.css" = mucssStylesheet;
    "cauldron.css" = ./cauldron.css;
    "cauldron.js" = ./cauldron.js;
    "favicon.ico" = "${pkgs.private-matrix-bootstrap.avatars}/the-cauldron.jpg";
    "avatars" = pkgs.private-matrix-bootstrap.avatars;
  };
in
{
  options.services.privateMatrix = {
    enable = lib.mkEnableOption "the private Matrix server on Malak";
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = noughtyLib.isHost [ "malak" ];
        message = "services.privateMatrix is restricted to Malak.";
      }
    ];

    nix.settings = lib.mkIf (noughtyLib.isHost [ "malak" ]) {
      extra-substituters = [ "https://cache.tuwunel.chat" ];
      extra-trusted-public-keys = [
        "cache.tuwunel.chat-1:ZafUaXiRMozDa9N2SWim6EdzH0EEjWjwfvlTxXvcjLA="
      ];
    };

    services.matrix-tuwunel = {
      enable = true;
      settings.global = {
        server_name = domain;
        address = [ "127.0.0.1" ];
        port = [ 6167 ];
        allow_registration = false;
        new_user_displayname_suffix = "";
        allow_guest_registration = false;
        allow_federation = false;
        federate_created_rooms = false;
        allow_encryption = false;
        encryption_enabled_by_default_for_room_type = "none";
        allow_legacy_media = false;
        allow_public_room_directory_over_federation = false;
        allow_public_room_directory_without_auth = false;
        require_auth_for_profile_requests = true;
        trusted_servers = [ ];
        registration_shared_secret_file = "/run/credentials/${tuwunelUnit}/${registrationSecret}";
        well_known = {
          client = "https://${domain}";
          support_mxid = "@martin:${domain}";
          support_role = "m.role.admin";
          support_page = "https://github.com/the-cauldron";
        };
      };
    };

    sops.secrets =
      lib.genAttrs
        [
          "MATRIX_PASSWORD_MARTIN"
          "MATRIX_PASSWORD_SKRYE"
          "MATRIX_PASSWORD_ZANNAH"
          "MATRIX_PASSWORD_TRAYA"
          registrationSecret
        ]
        (name: {
          sopsFile = ../../../../secrets/matrix.yaml;
          path = "/run/secrets/${name}";
          owner = "root";
          group = "root";
          mode = "0400";
        });

    systemd.services.tuwunel.serviceConfig.LoadCredential = [
      "${registrationSecret}:${config.sops.secrets.${registrationSecret}.path}"
    ];

    systemd.services.private-matrix-bootstrap = {
      description = "Provision private Matrix accounts and the-cauldron";
      wantedBy = [ "multi-user.target" ];
      requires = [ "tuwunel.service" ];
      after = [ "tuwunel.service" ];
      partOf = [ "tuwunel.service" ];
      restartTriggers = [ ../../../../secrets/matrix.yaml ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = "root";
        UMask = "0077";
        ExecStartPre = "${lib.getExe pkgs.curl} --fail --silent --output /dev/null --retry 20 --retry-connrefused --retry-delay 1 --retry-max-time 30 --max-time 2 http://127.0.0.1:6167/_matrix/client/versions";
        ExecStart = lib.getExe pkgs.private-matrix-bootstrap;
        TimeoutStartSec = 180;
      };
    };

    services.caddy = {
      enable = true;
      virtualHosts.${domain}.extraConfig = ''
        @restricted path /_synapse/* /_matrix/federation/* /_matrix/key/*
        handle @restricted {
          respond 403
        }
        @matrix path /_matrix/* /_tuwunel/* /.well-known/matrix/*
        handle @matrix {
          reverse_proxy 127.0.0.1:6167
        }
        handle {
          root * ${landingSite}
          file_server
        }
      '';
    };
  };
}
