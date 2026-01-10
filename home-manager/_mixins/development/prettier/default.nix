{
  config,
  lib,
  pkgs,
  username,
  ...
}:
let
  installFor = [ "martin" ];
in
lib.mkIf (lib.elem username installFor) {
  home = {
    packages = with pkgs; [
      # Single prettier installation for all editors
      nodePackages.prettier
    ];
  };

  programs = {
    vscode = lib.mkIf config.programs.vscode.enable {
      profiles.default = {
        userSettings = {
          # Set prettier as default formatter for supported languages
          "[css]"."editor.defaultFormatter" = "esbenp.prettier-vscode";
          "[html]"."editor.defaultFormatter" = "esbenp.prettier-vscode";
          "[javascript]"."editor.defaultFormatter" = "esbenp.prettier-vscode";
          "[javascriptreact]"."editor.defaultFormatter" = "esbenp.prettier-vscode";
          "[json]"."editor.defaultFormatter" = "esbenp.prettier-vscode";
          "[jsonc]"."editor.defaultFormatter" = "esbenp.prettier-vscode";
          "[typescript]"."editor.defaultFormatter" = "esbenp.prettier-vscode";
          "[typescriptreact]"."editor.defaultFormatter" = "esbenp.prettier-vscode";
        };
        extensions = with pkgs; [
          vscode-marketplace.esbenp.prettier-vscode
        ];
      };
    };
    zed-editor = lib.mkIf config.programs.zed-editor.enable {
      userSettings = {
        # Prettier formatting for web languages
        languages = {
          CSS = {
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
          HTML = {
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
          JavaScript = {
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
          JSON = {
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
          JSONC = {
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
          TSX = {
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
          TypeScript = {
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
    neovim = lib.mkIf config.programs.neovim.enable {
      extraLuaConfig = ''
        -- Prettier formatting for web languages (CSS, HTML, JS, JSON, TS)
        require('conform').formatters_by_ft.css = { 'prettier' }
        require('conform').formatters_by_ft.html = { 'prettier' }
        require('conform').formatters_by_ft.javascript = { 'prettier' }
        require('conform').formatters_by_ft.javascriptreact = { 'prettier' }
        require('conform').formatters_by_ft.json = { 'prettier' }
        require('conform').formatters_by_ft.jsonc = { 'prettier' }
        require('conform').formatters_by_ft.typescript = { 'prettier' }
        require('conform').formatters_by_ft.typescriptreact = { 'prettier' }
      '';
    };
  };
}
