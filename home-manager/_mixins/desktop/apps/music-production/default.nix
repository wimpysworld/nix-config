{
  config,
  inputs,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  resourcePath = config.programs.reaper.configPath;
  profile = config.home.profileDirectory;
  assets = "${pkgs.twelvetake-reaper-mcp}/share/twelvetake-reaper-mcp";
  startupHelper = pkgs.runCommand "reaper-mcp-startup" { nativeBuildInputs = [ pkgs.python3 ]; } ''
    python3 ${./test-merge-startup.py} ${./merge-startup.py}
    install -Dm644 ${./merge-startup.py} "$out/share/reaper-mcp/merge-startup.py"
  '';
  plugInPaths = {
    enableNixPaths = false;
    enableUserPaths = false;
    mutable = true;
  };
in
{
  imports = [ inputs.reaper-flake.homeModules.reaper ];

  config = lib.mkIf (host.is.nixos && host.is.workstation && noughtyLib.hostHasTag "studio") {
    programs.reaper = {
      enable = true;
      basePackage = pkgs.reaper;
      configPath = "${config.xdg.configHome}/REAPER";
      activation.allowRunning = false;
      preferences.plugIns = {
        vst = plugInPaths // {
          searchPaths = [
            "${profile}/lib/vst"
            "${profile}/lib/vst3"
          ];
        };
        lv2 = plugInPaths // {
          searchPaths = [ "${profile}/lib/lv2" ];
        };
        clap = plugInPaths // {
          searchPaths = [ "${profile}/lib/clap" ];
        };
      };
    };

    home.packages =
      lib.concatMap
        (
          package:
          lib.optionals (
            lib.meta.availableOn pkgs.stdenv.hostPlatform package && !(package.meta.broken or false)
          ) [ package ]
        )
        (
          with pkgs;
          [
            surge-xt
            vital
            dexed
            odin2
            zynaddsubfx
            geonkick
            unstable.jc303
            x42-avldrums
            sfizz-ui
            guitarix
            setbfree
            lsp-plugins
            dragonfly-reverb
            chow-tape-model
          ]
        )
      ++ lib.optional (
        lib.meta.availableOn pkgs.stdenv.hostPlatform pkgs.sfizz-ui && !(pkgs.sfizz-ui.meta.broken or false)
      ) (pkgs.callPackage ./sfizz-presets.nix { });

    xdg.dataFile = {
      "sfz/README.md".source = ./README.md;
      "sfz/karoryfer-black-and-green-guitars".source =
        "${pkgs.karoryfer-black-and-green-guitars}/share/sfz/karoryfer-black-and-green-guitars";
      "sfz/karoryfer-growlybass".source = "${pkgs.karoryfer-growlybass}/share/sfz/karoryfer-growlybass";
      "sfz/freepats-synthesizer-percussion".source =
        "${pkgs.freepats-synthesizer-percussion}/share/sfz/freepats-synthesizer-percussion";
    };

    home.file = {
      "${resourcePath}/Scripts/reaper_mcp_bridge.lua".source = "${assets}/reaper_mcp_bridge.lua";
      "${resourcePath}/Effects/TwelveTake/twelvetake_mcp_analyzer.jsfx".source =
        "${assets}/twelvetake_mcp_analyzer.jsfx";
      "${resourcePath}/Effects/Saike/Filther".source =
        "${pkgs.saike-jsfx}/share/reaper/Effects/Saike/Filther";
      "${resourcePath}/Effects/Saike/Squashman".source =
        "${pkgs.saike-jsfx}/share/reaper/Effects/Saike/Squashman";
    };

    home.activation = {
      reaperMcpGuard = lib.hm.dag.entryBefore [ "writeBoundary" ] ''
        if ${pkgs.runtimeShell} ${inputs.reaper-flake}/scripts/reaper-is-running.sh ${pkgs.procps}/bin/pgrep; then
          echo "Close REAPER before activating its configuration and MCP bridge." >&2
          exit 1
        fi
      '';
      reaperMcpStartup = lib.hm.dag.entryAfter [ "reaper" "linkGeneration" ] ''
        run ${pkgs.coreutils}/bin/mkdir -p ${lib.escapeShellArg "${resourcePath}/Scripts/mcp_bridge_data"}
        run ${pkgs.python3}/bin/python3 ${startupHelper}/share/reaper-mcp/merge-startup.py \
          ${lib.escapeShellArg "${resourcePath}/Scripts/__startup.lua"}
      '';
    };
  };
}
