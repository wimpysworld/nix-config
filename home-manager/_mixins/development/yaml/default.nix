{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
in
{
  home = {
    packages =
      with pkgs;
      [
        yq-go # Terminal `jq` for YAML
      ]
      ++ lib.optional (!host.is.server) yaml-language-server;
  };

  programs = {
    zed-editor = lib.mkIf config.programs.zed-editor.enable {
      userSettings = {
        languages = {
          YAML = {
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
        lsp = lib.mkIf (!host.is.server) {
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

  claude-code.lspServers = lib.mkIf (!host.is.server && config.programs.claude-code.enable) {
    yaml = {
      command = lib.getExe pkgs.yaml-language-server;
      args = [ "--stdio" ];
      extensionToLanguage = {
        ".yaml" = "yaml";
        ".yml" = "yaml";
      };
    };
  };

  fresh.settings.lsp.yaml = lib.mkIf (!host.is.server) {
    command = lib.getExe pkgs.yaml-language-server;
    args = [ "--stdio" ];
    enabled = true;
    auto_start = true;
    initialization_options.yaml.keyOrdering = true;
  };
}
