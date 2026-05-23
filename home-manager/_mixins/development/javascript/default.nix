{
  config,
  lib,
  pkgs,
  ...
}:
{
  home = {
    packages = with pkgs; [
      # Node.js runtime and package manager
      nodejs

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

  claude-code.lspServers = {
    typescript = {
      command = lib.getExe pkgs.typescript-language-server;
      args = [ "--stdio" ];
      extensionToLanguage = {
        ".ts" = "typescript";
        ".tsx" = "typescriptreact";
        ".js" = "javascript";
        ".jsx" = "javascriptreact";
        ".mjs" = "javascript";
        ".mts" = "typescript";
        ".cjs" = "javascript";
        ".cts" = "typescript";
      };
    };
    json = {
      command = "${pkgs.vscode-langservers-extracted}/bin/vscode-json-language-server";
      args = [ "--stdio" ];
      extensionToLanguage = {
        ".json" = "json";
        ".jsonc" = "jsonc";
      };
    };
    html = {
      command = "${pkgs.vscode-langservers-extracted}/bin/vscode-html-language-server";
      args = [ "--stdio" ];
      extensionToLanguage = {
        ".html" = "html";
      };
    };
    css = {
      command = "${pkgs.vscode-langservers-extracted}/bin/vscode-css-language-server";
      args = [ "--stdio" ];
      extensionToLanguage = {
        ".css" = "css";
        ".scss" = "scss";
        ".less" = "less";
      };
    };
  };

  fresh.settings.lsp = {
    javascript = {
      command = lib.getExe pkgs.typescript-language-server;
      args = [ "--stdio" ];
      enabled = true;
      auto_start = true;
    };
    typescript = {
      command = lib.getExe pkgs.typescript-language-server;
      args = [ "--stdio" ];
      enabled = true;
      auto_start = true;
    };
    json = {
      command = "${pkgs.vscode-langservers-extracted}/bin/vscode-json-language-server";
      args = [ "--stdio" ];
      enabled = true;
      auto_start = true;
    };
    html = {
      command = "${pkgs.vscode-langservers-extracted}/bin/vscode-html-language-server";
      args = [ "--stdio" ];
      enabled = true;
      auto_start = true;
    };
    css = {
      command = "${pkgs.vscode-langservers-extracted}/bin/vscode-css-language-server";
      args = [ "--stdio" ];
      enabled = true;
      auto_start = true;
    };
  };
}
