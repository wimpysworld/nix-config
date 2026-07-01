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
in
lib.mkIf isDeveloper {
  home = {
    packages =
      lib.optionals (!host.is.server) [
        pkgs.rumdl # Markdown linter
      ]
      ++ lib.optionals isWorkstationDeveloper [
        pkgs.marp-cli # Terminal Markdown presenter
      ];
  };

  programs = {
    zed-editor = lib.mkIf config.programs.zed-editor.enable {
      extensions = [
        "emoji-completions"
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
