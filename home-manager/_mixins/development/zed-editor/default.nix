{
  config,
  lib,
  pkgs,
  username,
  ...
}:
let
  installFor = [ "martin" ];
  inherit (pkgs.stdenv) isLinux;
in
lib.mkIf (lib.elem username installFor && isLinux) {
  catppuccin.zed.enable = config.programs.zed-editor.enable;
  programs = {
    zed-editor = {
      enable = true;
      extensions = [
        "github-actions"
        "lua"
        "nix"
      ];
      package = pkgs.unstable.zed-editor;
      userSettings = {
        "languages" = {
          "Nix" = {
            "formatter" = {
              "external" = {
                "command" = "nixfmt";
                "arguments" = [
                  "--quiet"
                  "--"
                ];
              };
            };
            "language_servers" = [
              "nil"
              "!nixd"
            ];
          };
        };
        "lsp" = {
          "nil" = {
            "settings" = {
              "diagnostics" = {
                "ignored" = [ "unused_binding" ];
              };
            };
          };
        };
      };
    };
  };
}
