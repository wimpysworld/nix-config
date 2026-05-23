{
  config,
  lib,
  pkgs,
  ...
}:
{
  home = {
    packages = with pkgs; [
      yaml-language-server
      yq-go # Terminal `jq` for YAML
    ];
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

  claude-code.lspServers.yaml = {
    command = lib.getExe pkgs.yaml-language-server;
    args = [ "--stdio" ];
    extensionToLanguage = {
      ".yaml" = "yaml";
      ".yml" = "yaml";
    };
  };

  fresh.settings.lsp.yaml = {
    command = lib.getExe pkgs.yaml-language-server;
    args = [ "--stdio" ];
    enabled = true;
    auto_start = true;
    initialization_options.yaml.keyOrdering = true;
  };
}
