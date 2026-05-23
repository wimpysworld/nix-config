{
  config,
  lib,
  pkgs,
  ...
}:
{
  home = {
    # Packages that are used by some of the extensions below
    packages = with pkgs; [
      just
      just-formatter
      just-lsp
    ];
  };

  programs = {
    zed-editor = lib.mkIf config.programs.zed-editor.enable {
      extensions = [
        "just"
        "just-ls"
      ];
      userSettings = {
        languages = {
          Just = {
            formatter = {
              external = {
                command = "${pkgs.just-formatter}/bin/just-formatter";
              };
            };
            language_servers = [
              "just-lsp"
            ];
          };
        };
        lsp = {
          just-lsp = { };
        };
      };
    };
  };
}
