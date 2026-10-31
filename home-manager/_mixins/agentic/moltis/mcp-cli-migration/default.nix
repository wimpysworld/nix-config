{ pkgs }:
pkgs.writeShellApplication {
  name = "moltis-mcp-cli-migration";
  runtimeInputs = [ pkgs.python3 ];
  text = ''
    exec python3 ${./migrate.py} "$@"
  '';
}
