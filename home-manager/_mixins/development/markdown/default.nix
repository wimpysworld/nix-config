{
  config,
  lib,
  pkgs,
  ...
}:
{
  home = {
    packages = with pkgs; [
      marp-cli # Terminal Markdown presenter
      rumdl # Markdown linter
    ];
  };

  programs = {
    zed-editor = lib.mkIf config.programs.zed-editor.enable {
      extensions = [
        "emoji-completions"
        "rumdl"
      ];
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
