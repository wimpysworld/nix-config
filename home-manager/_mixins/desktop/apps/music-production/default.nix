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
  ludwig = "${pkgs.tchackpoum-ludwig-black-cortex}/share/reaper";
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
            unstable.decent-sampler
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
      "sfz/acoustic-drums.md".source = ./acoustic-drums.md;
      "sfz/guitars-and-basses.md".source = ./guitars-and-basses.md;
      "sfz/karoryfer-big-rusty-drums".source =
        "${pkgs.karoryfer-big-rusty-drums}/share/sfz/karoryfer-big-rusty-drums";
      "sfz/virtuosity-drums".source = "${pkgs.virtuosity-drums}/share/sfz/virtuosity-drums";
      "reaper-libraries/tchackpoum-ludwig-black-cortex".source =
        "${pkgs.tchackpoum-ludwig-black-cortex}/share/tchackpoum-ludwig-black-cortex";
      "sfz/karoryfer-black-and-green-guitars".source =
        "${pkgs.karoryfer-black-and-green-guitars}/share/sfz/karoryfer-black-and-green-guitars";
      "sfz/karoryfer-growlybass".source = "${pkgs.karoryfer-growlybass}/share/sfz/karoryfer-growlybass";
      "sfz/karoryfer-black-and-blue-basses".source =
        "${pkgs.karoryfer-black-and-blue-basses}/share/sfz/karoryfer-black-and-blue-basses";
      "sfz/karoryfer-pastabass".source = "${pkgs.karoryfer-pastabass}/share/sfz/karoryfer-pastabass";
      "sfz/project16-rickenbacker-4001".source =
        "${pkgs.project16-rickenbacker-4001}/share/sfz/project16-rickenbacker-4001";
      "sfz/unreal-the-slapper".source = "${pkgs.unreal-the-slapper}/share/sfz/unreal-the-slapper";
      "sfz/freepats-synthesizer-percussion".source =
        "${pkgs.freepats-synthesizer-percussion}/share/sfz/freepats-synthesizer-percussion";
    };

    home.file = {
      "${resourcePath}/TrackTemplates/Tchackpoum/ReaperDrummer Ludwig Black Cortex keyboard.RTrackTemplate".source =
        "${ludwig}/TrackTemplates/Tchackpoum/ReaperDrummer Ludwig Black Cortex keyboard.RTrackTemplate";
      "${resourcePath}/TrackTemplates/Tchackpoum/ReaperDrummer Ludwig Black Cortex.RTrackTemplate".source =
        "${ludwig}/TrackTemplates/Tchackpoum/ReaperDrummer Ludwig Black Cortex.RTrackTemplate";
      "${resourcePath}/Effects/Tchackpoum/LudwigBlackCortex".source =
        "${ludwig}/Effects/Tchackpoum/LudwigBlackCortex";
      "${resourcePath}/MIDINoteNames/Tchackpoum".source = "${ludwig}/MIDINoteNames/Tchackpoum";
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
