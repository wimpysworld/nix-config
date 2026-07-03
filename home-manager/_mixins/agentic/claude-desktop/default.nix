{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;

  # Claude Desktop is a graphical Electron application sourced from the
  # llm-agents flake, so it is available on Linux only and belongs on
  # workstations rather than servers or headless hosts.
  desktopEnabled = host.is.workstation && host.is.linux;
in
{
  config = lib.mkIf desktopEnabled {
    home.packages = [ pkgs.claude-desktop ];
  };
}
