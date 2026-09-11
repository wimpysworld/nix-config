{ pkgs, ... }:
pkgs.writeShellApplication {
  name = "deploy-owned-agent-files";
  runtimeInputs = [ pkgs.python3 ];
  text = ''
    exec python3 ${./deploy.py} "$@"
  '';
}
