# The scripts hub imports only default.nix. The mint-tokens module also builds
# this package, so that it can import the session variables itself.
{
  desktop,
  lib,
  pkgs,
}:
let
  name = "session-env";
  inherit ((import ../../../../lib/wayland-compositors.nix)) compositors;
  compositor =
    if builtins.isString desktop then lib.attrByPath [ desktop ] null compositors else null;
  # These are the variables that the compositor imports into the user manager
  # and removes again at logout, with a generic fallback for a desktop outside
  # the compositor contract.
  allowList =
    if compositor != null then
      compositor.ephemeralEnvironment
    else
      [
        "DISPLAY"
        "WAYLAND_DISPLAY"
        "XDG_SESSION_TYPE"
        "XDG_CURRENT_DESKTOP"
      ];
in
pkgs.writeShellApplication {
  inherit name;
  runtimeInputs = [ ];
  # systemctl comes from the system PATH, so that it matches the running
  # user manager.
  text = ''
    set -- ${lib.escapeShellArgs allowList} -- "$@"
  ''
  + lib.removePrefix "#!/usr/bin/env bash\n" (builtins.readFile ./${name}.sh);
}
