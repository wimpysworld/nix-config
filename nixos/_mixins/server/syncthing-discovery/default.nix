{
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  network = import ../../../../lib/syncthing-network.nix;
in
lib.mkIf (noughtyLib.isHost [ "malak" ]) {
  systemd.services.syncthing-discovery = {
    description = "Syncthing discovery service";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    serviceConfig = {
      DynamicUser = true;
      StateDirectory = "syncthing-discovery";
      StateDirectoryMode = "0700";
      WorkingDirectory = "/var/lib/syncthing-discovery";
      ExecStart = "${lib.getExe pkgs.syncthing-discovery} --http --listen=127.0.0.1:8443 --db-dir=/var/lib/syncthing-discovery";
      Restart = "on-failure";
      UMask = "0077";
    };
  };

  services.caddy.virtualHosts.${network.hostname}.extraConfig = ''
    reverse_proxy 127.0.0.1:8443 {
      header_up X-Forwarded-For {http.request.remote.host}
      header_up X-Client-Port {http.request.remote.port}
      header_up X-Tls-Client-Cert-Der-Base64 {http.request.tls.client.certificate_der_base64}
      header_up -X-Ssl-Cert
      header_up -X-Forwarded-Tls-Client-Cert
    }
    tls {
      client_auth {
        mode request
      }
    }
  '';
}
