# Harper - privacy-first grammar and spelling checking.
# Centralised configuration for editor and coding-agent integrations.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  harperLs = "${pkgs.harper}/bin/harper-ls";

  harperSettings = {
    dialect = "British";
    diagnosticSeverity = "hint";
  };

  neovimFiletypes = [
    "markdown"
    "text"
    "tex"
    "typst"
  ];

  extensionToLanguage = {
    ".adoc" = "asciidoc";
    ".asciidoc" = "asciidoc";
    ".c" = "c";
    ".cc" = "cpp";
    ".clj" = "clojure";
    ".cljc" = "clojure";
    ".cljs" = "clojure";
    ".cmake" = "cmake";
    ".cpp" = "cpp";
    ".cs" = "csharp";
    ".cxx" = "cpp";
    ".dart" = "dart";
    ".go" = "go";
    ".groovy" = "groovy";
    ".h" = "c";
    ".hs" = "haskell";
    ".html" = "html";
    ".java" = "java";
    ".js" = "javascript";
    ".jsx" = "javascriptreact";
    ".kt" = "kotlin";
    ".kts" = "kotlin";
    ".lhs" = "lhaskell";
    ".lua" = "lua";
    ".md" = "markdown";
    ".mdx" = "markdown";
    ".nix" = "nix";
    ".org" = "org";
    ".php" = "php";
    ".ps1" = "powershell";
    ".py" = "python";
    ".rb" = "ruby";
    ".rs" = "rust";
    ".scala" = "scala";
    ".sh" = "shellscript";
    ".sol" = "solidity";
    ".swift" = "swift";
    ".tex" = "tex";
    ".toml" = "toml";
    ".ts" = "typescript";
    ".tsx" = "typescriptreact";
    ".txt" = "plaintext";
    ".typ" = "typst";
    ".zig" = "zig";
  };

  extensions = lib.attrNames extensionToLanguage;
in
{
  home.packages = [ pkgs.harper ];

  # Claude Code - LSP server plugin.
  claude-code.lspServers.harper = {
    command = harperLs;
    args = [ "--stdio" ];
    inherit extensionToLanguage;
    initializationOptions = {
      "harper-ls" = harperSettings;
    };
  };

  # OpenCode - LSP server.
  programs.opencode.settings.lsp.harper = {
    command = [
      harperLs
      "--stdio"
    ];
    inherit extensions;
    initialization = {
      "harper-ls" = harperSettings;
    };
  };

  # Zed Editor - extension and LSP settings.
  programs.zed-editor = lib.mkIf config.programs.zed-editor.enable {
    extensions = [ "harper" ];
    userSettings.lsp."harper-ls" = {
      binary = {
        path = harperLs;
        arguments = [ "--stdio" ];
      };
      settings."harper-ls" = harperSettings;
    };
  };

  # Neovim - native LSP configuration.
  programs.neovim = lib.mkIf config.programs.neovim.enable {
    extraLuaConfig = ''
      -- Harper grammar and spelling LSP using Neovim 0.11+ native API.
      vim.lsp.config('harper', {
        cmd = { '${harperLs}', '--stdio' },
        filetypes = ${builtins.toJSON neovimFiletypes},
        settings = {
          ['harper-ls'] = {
            dialect = 'British',
            diagnosticSeverity = 'hint',
          },
        },
      })
      vim.lsp.enable('harper')
    '';
  };
}
