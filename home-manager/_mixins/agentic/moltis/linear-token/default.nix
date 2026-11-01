{
  pkgs,
  lib,
  mcporter,
  clientIdPath,
  clientSecretPath,
  cacheDirectory,
  configPath,
  linearUrl,
}:
let
  linearServer = pkgs.writeShellApplication {
    name = "moltis-linear-server";
    runtimeInputs = [ pkgs.python3 ];
    text = ''
      exec python3 ${./linear_token.py} linear-server \
        ${lib.escapeShellArg clientIdPath} \
        ${lib.escapeShellArg clientSecretPath} \
        ${lib.escapeShellArg cacheDirectory} \
        ${lib.getExe pkgs.mcp-proxy} \
        ${lib.escapeShellArg linearUrl}
    '';
  };
in
pkgs.writeShellApplication {
  name = "mcporter";
  runtimeInputs = [ pkgs.python3 ];
  derivationArgs.passthru = { inherit linearServer; };
  text = ''
    exec python3 ${./linear_token.py} mcporter \
      ${lib.escapeShellArg configPath} \
      ${lib.getExe mcporter} "$@"
  '';
}
