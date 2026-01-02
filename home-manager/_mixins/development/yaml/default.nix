{
  config,
  isWorkstation,
  lib,
  pkgs,
  username,
  ...
}:
let
  installFor = [ "martin" ];
in
lib.mkIf (lib.elem username installFor && isWorkstation) {
  home = {
    packages = with pkgs; [
      yaml-language-server
      yq-go # Terminal `jq` for YAML
    ];
  };

  programs = {
    vscode = lib.mkIf config.programs.vscode.enable {
      profiles.default = {
        userSettings = {
          "redhat.telemetry.enabled" = false;
          "yaml.keyOrdering" = true;
        };
        extensions = with pkgs; [
          vscode-marketplace.redhat.vscode-yaml
        ];
      };
    };
    zed-editor = lib.mkIf config.programs.zed-editor.enable {
      userSettings = {
        lsp = {
          yaml-language-server = {
            settings = {
              yaml = {
                # Enforces alphabetical ordering of keys in maps
                keyOrdering = true;
              };
            };
          };
        };
      };
    };
  };
}
