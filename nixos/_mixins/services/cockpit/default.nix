{ hostname, lib, pkgs, ... }:
{
  imports = lib.optional (builtins.pathExists (./. + "/${hostname}.nix")) ./${hostname}.nix;
  services.cockpit = {
    enable = true;
    port = 9090;
    settings = {
      WebService = {
        Origins = "https://${hostname}.drongo-gama.ts.net wss://${hostname}.drongo-gama.ts.net http://127.0.0.1:9090";
        ProtocolHeader = "X-Forwarded-Proto";
        #ForwardedForHeader = "X-Forwarded-For";
        UrlRoot = "/cockpit";
        AllowUnencrypted = true;
      };
    };
  };
}
