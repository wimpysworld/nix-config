{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  shellApplication = import ./package.nix {
    inherit lib pkgs;
    inherit (host) desktop;
  };
  sessionEnv = lib.getExe shellApplication;
in
lib.mkIf (host.is.linux && host.is.workstation) {
  home.packages = [ shellApplication ];

  # A Herdr pane inherits the environment of the Herdr server, which can start
  # outside the graphical session or outlive it. A pane therefore always takes
  # the current values from the user manager. Any other shell imports them
  # only when it has no Wayland or X11 display, so a desktop terminal starts no
  # extra process.
  programs.bash.initExtra = ''
    if [[ -n "''${HERDR_ENV:-}" ]] || [[ -z "''${WAYLAND_DISPLAY:-}" && -z "''${DISPLAY:-}" ]]; then
        eval "$(${sessionEnv})"
    fi
  '';

  programs.fish.interactiveShellInit = ''
    if test -n "$HERDR_ENV"; or begin
            test -z "$WAYLAND_DISPLAY"; and test -z "$DISPLAY"
        end
        ${sessionEnv} --fish | source
    end
  '';
}
