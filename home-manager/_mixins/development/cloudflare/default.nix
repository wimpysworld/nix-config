{
  config,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
in
lib.mkIf
  (host.is.workstation && noughtyLib.userHasTag "developer" && noughtyLib.isUser [ "martin" ])
  {
    # Prefer standalone TypeScript over Wrangler's bundled copy in the profile.
    home.packages = [
      (lib.lowPrio pkgs.wrangler)
      (pkgs.callPackage ./wrangler {
        accountIdPath = config.sops.secrets.CLOUDFLARE_ACCOUNT_ID.path;
        apiTokenPath = config.sops.secrets.CLOUDFLARE_API_TOKEN.path;
      })
    ];

    sops.secrets =
      lib.genAttrs
        [
          "CLOUDFLARE_ACCOUNT_ID"
          "CLOUDFLARE_API_TOKEN"
        ]
        (key: {
          inherit key;
          sopsFile = ../../../../secrets/cloudflare.yaml;
          mode = "0400";
        });
  }
