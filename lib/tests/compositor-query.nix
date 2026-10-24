# Runs compositor-query, wleave-session, xwayland-dpi and the fuzzel-capture
# output mapping against fake Mango and Wayfire tools, with the logical output
# geometry of skrye, zannah, ravi, tanis and bane. The flake check `checks.<system>.compositor-query` runs this
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
      "compositor-wayfire-ipc"
      "mmsg"
      "wleave"
      "wlr-randr"
      "xrdb"
    ];
  };
  # No compositor tools in runtimeInputs, so the fakes resolve from PATH.
  compositorQuery =
    import ../../home-manager/_mixins/desktop/compositor/components/compositor-query/package.nix
      {
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
  # The fuzzel-capture functions without the final sub-command dispatch, so
  # the test calls the output mapping that region and window recording use.
  captureParts = lib.splitString "\ncase \"\${1:-menu}\" in\n" (
    builtins.replaceStrings [ "@wlScreenrec@" ] [ "/dev/null" ] (
      builtins.readFile ../../home-manager/_mixins/desktop/compositor/components/capture/fuzzel-capture.sh
    )
  );
  captureMapping =
    assert lib.assertMsg (
      builtins.length captureParts == 2
    ) "lib/tests/compositor-query.nix: cannot find the fuzzel-capture dispatch";
    pkgs.writeShellApplication {
      name = "capture-mapping";
      runtimeInputs = [
        compositorQuery
        pkgs.jq
      ];
      # The dispatch below calls only the output mapping functions.
      excludeShellChecks = [ "SC2329" ];
      text = builtins.head captureParts + ''

        case "$1" in
        outputs) find_region_outputs "$2" ;;
        clamp) clamp_region_to_output "$2" "$3" ;;
        esac
      '';
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
    ${lib.getExe wleaveSession} ${lib.getExe xwaylandDpi} ${lib.getExe captureMapping}
''
