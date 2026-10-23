# Runs compositor-query, wleave-session and xwayland-dpi against fake Mango
# and Wayfire tools, with the logical output geometry of skrye, zannah, ravi,
# tanis and bane. The flake check `checks.<system>.compositor-query` runs this
# test.
{ pkgs }:
let
  inherit (pkgs) lib;
  fakeCommand =
    name:
    pkgs.writeShellApplication {
      inherit name;
      text = ''
        set -- ${lib.escapeShellArg name} "$@"
      ''
      + lib.removePrefix "#!/usr/bin/env bash\n" (builtins.readFile ./compositor-query-fake-command.sh);
    };
  fakeCommands = pkgs.symlinkJoin {
    name = "compositor-query-fake-commands";
    paths = map fakeCommand [
      "lan-mouse-wayfire-ipc"
      "mmsg"
      "wleave"
      "wlr-randr"
      "xrdb"
    ];
  };
  # No compositor tools in runtimeInputs, so the fakes resolve from PATH.
  compositorQuery = import ../../home-manager/_mixins/scripts/lan-mouse-warp/compositor-query.nix {
    inherit pkgs;
    compositorTools = [ ];
  };
  wleaveSession = pkgs.writeShellApplication {
    name = "wleave-session";
    runtimeInputs = [ compositorQuery ];
    text = ''
      wleave=wleave
      config_home=/empty
      layout=layout.json
      css=style.css
    ''
    + lib.removePrefix "#!/usr/bin/env bash\n" (
      builtins.readFile ../../home-manager/_mixins/desktop/compositor/components/wleave/wleave-session.sh
    );
  };
  xwaylandDpi = pkgs.writeShellApplication {
    name = "xwayland-dpi";
    runtimeInputs = [
      compositorQuery
      pkgs.jq
    ];
    text = ''
      primary=''${TEST_PRIMARY:?}
    ''
    + lib.removePrefix "#!/usr/bin/env bash\n" (
      builtins.readFile ../../home-manager/_mixins/desktop/compositor/mango/xwayland-dpi.sh
    );
  };
in
pkgs.runCommand "compositor-query" { } ''
  export PATH=${
    lib.makeBinPath [
      fakeCommands
      pkgs.bash
      pkgs.coreutils
      pkgs.diffutils
      pkgs.jq
      pkgs.python3
    ]
  }
  exec bash ${./compositor-query.sh} ${lib.getExe compositorQuery} \
    ${lib.getExe wleaveSession} ${lib.getExe xwaylandDpi}
''
