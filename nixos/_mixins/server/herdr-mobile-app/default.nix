{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  inherit (import ../../../../lib/herdr-mobile-app.nix { inherit (config.noughty.network) tailNet; })
    appUrls
    ;
in
# The phone app holds every relay key and device credential in browser storage,
# which is per origin. A dedicated port keeps that origin apart from Syncthing
# and noVNC on the main tailnet site.
lib.mkIf (appUrls ? ${host.name} && config.services.tailscale.enable) {
  services.caddy.virtualHosts.herdr-mobile-app = {
    hostName = appUrls.${host.name};
    logFormat = ''
      output file /var/log/caddy/herdr-mobile-app.log
    '';
    # Caddy does not read the Cloudflare Pages `_headers` file in the app, so
    # its cache rules are repeated here, with the relay's own security headers.
    extraConfig = ''
      route {
        @notTailscale {
          not remote_ip 100.64.0.0/10 fd7a:115c:a1e0::/48
        }
        respond @notTailscale 403

        header {
          X-Content-Type-Options nosniff
          X-Frame-Options DENY
          Referrer-Policy no-referrer
          Permissions-Policy "camera=(self), microphone=(), geolocation=()"
          Content-Security-Policy "default-src 'self'; connect-src 'self' https: wss:; img-src 'self' blob: data:; media-src blob:; style-src 'self'; style-src-attr 'unsafe-inline'; script-src 'self'; worker-src 'self'; manifest-src 'self'; object-src 'none'; base-uri 'none'; frame-ancestors 'none'"
        }

        @noCacheNoStore path / /index.html /herdr-bootstrap.js /manifest-loader.js /manifest.webmanifest /setup.webmanifest /sw.js /version.json /release.json
        header @noCacheNoStore Cache-Control "no-cache, no-store"
        @noStore path /404.html /404
        header @noStore Cache-Control "no-store"
        @noCache path /builds/* /assets/*
        header @noCache Cache-Control "no-cache"

        root * ${pkgs.herdr-mobile-relay.passthru.webRoot}
        file_server {
          precompressed br
        }
      }
    '';
  };
}
