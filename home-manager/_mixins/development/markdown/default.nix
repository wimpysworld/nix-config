{
  config,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  isDeveloper = noughtyLib.userHasTag "developer";
  isWorkstationDeveloper = isDeveloper && host.is.workstation;
  marpExportTests = pkgs.runCommand "marp-export-tests" { } ''
    cp ${../../agentic/assistants/skills/marp-presentations/scripts/export.py} export.py
    cp ${../../agentic/assistants/skills/marp-presentations/scripts/test_export.py} test_export.py
    PYTHONDONTWRITEBYTECODE=1 ${pkgs.python3}/bin/python3 -m unittest -v test_export
    touch "$out"
  '';
  marpCli = pkgs.symlinkJoin {
    name = "marp-cli-validated";
    paths = [ pkgs.marp-cli ];
    postBuild = ''
      test -f ${marpExportTests}
    '';
  };
in
lib.mkIf isDeveloper {
  home = {
    packages =
      lib.optionals (!host.is.server) [
        pkgs.rumdl # Markdown linter
      ]
      ++ lib.optionals isWorkstationDeveloper [
        marpCli
        pkgs.fontconfig
        pkgs.python3
      ];
  };

  programs = {
    zed-editor = lib.mkIf config.programs.zed-editor.enable {
      extensions = [
        "emoji-completions"
        "zk"
      ]
      ++ lib.optional (!host.is.server) "rumdl";
      userSettings = {
        languages = {
          Markdown = {
            formatter = {
              external = {
                command = "prettier";
                arguments = [
                  "--stdin-filepath"
                  "{buffer_path}"
                ];
              };
            };
          };
        };
      };
    };
  };
}
