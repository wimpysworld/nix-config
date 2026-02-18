{
  config,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
lib.mkIf (noughtyLib.isUser [ "martin" ]) {
  home = {
    packages = with pkgs; [
      # Node.js runtime and package manager
      nodejs_24

      # JavaScript/TypeScript tooling
      unstable.bun
      prettier
      tsx
      typescript
      typescript-language-server
      vscode-js-debug
      vtsls

      # Language servers for web technologies
      vscode-langservers-extracted # JSON, HTML, CSS, ESLint
    ];
  };

  programs = {
    neovim = lib.mkIf config.programs.neovim.enable {
      plugins = [
        (pkgs.vimPlugins.nvim-treesitter.withPlugins (p: [
          p.css
          p.html
          p.javascript
          p.json
          p.tsx
          p.typescript
        ]))
      ];
      extraLuaConfig = ''
        -- JavaScript/TypeScript LSP (ts_ls) using Neovim 0.11+ native API
        vim.lsp.enable('ts_ls')
        -- JSON/CSS/HTML LSPs using Neovim 0.11+ native API
        vim.lsp.enable({'jsonls', 'cssls', 'html'})
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
    opencode = lib.mkIf config.programs.opencode.enable {
      settings = {
        formatter = {
          # Prettier: format web languages (JS/TS/CSS/HTML/JSON)
          prettier = {
            command = [
              "${pkgs.prettier}/bin/prettier"
              "--write"
              "$FILE"
            ];
            extensions = [
              ".js"
              ".jsx"
              ".ts"
              ".tsx"
              ".html"
              ".css"
              ".scss"
              ".less"
              ".json"
              ".jsonc"
            ];
          };
        };
      };
    };
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
  };
}
