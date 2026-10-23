# Runs mango-pinned-watch against a fake mmsg that replays one monitor event
# and records each dispatch. The flake check `checks.<system>.mango-pinned-watch`
# runs this test.
{ pkgs }:
let
  owners = builtins.toJSON {
    "1" = "eDP-1";
    "2" = "eDP-1";
    "3" = "eDP-1";
    "4" = "eDP-1";
    "5" = "eDP-1";
    "6" = "eDP-1";
    "7" = "eDP-1";
    "8" = "DP-3";
  };
  watcher = pkgs.writeShellApplication {
    name = "mango-pinned-watch";
    runtimeInputs = [ pkgs.jq ];
    text = ''
      owners=${pkgs.lib.escapeShellArg owners}
    ''
    + builtins.readFile ../../home-manager/_mixins/desktop/compositor/mango/mango-pinned-watch.sh;
  };
  fakeMmsg = pkgs.writeShellApplication {
    name = "mmsg";
    runtimeInputs = [ pkgs.coreutils ];
    text = builtins.readFile ./mango-pinned-watch-fake-mmsg.sh;
  };
in
pkgs.runCommand "mango-pinned-watch" { } ''
  export PATH=${
    pkgs.lib.makeBinPath [
      fakeMmsg
      pkgs.bash
      pkgs.coreutils
      pkgs.diffutils
      pkgs.jq
    ]
  }
  exec bash ${./mango-pinned-watch.sh} ${pkgs.lib.getExe watcher}
''
