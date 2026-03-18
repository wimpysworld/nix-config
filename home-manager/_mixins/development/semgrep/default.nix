# Semgrep - cross-language static analysis
# Centralised configuration for all IDE and coding tool integrations.
{
  config,
  lib,
  pkgs,
  ...
}:
{
  home.packages = [ pkgs.semgrep ];

  # Claude Code - LSP server plugin
  claude-code.lspServers.semgrep = {
    command = "${pkgs.semgrep}/bin/semgrep";
    args = [ "lsp" ];
    extensionToLanguage = {
      ".R" = "r";
      ".bash" = "shellscript";
      ".c" = "c";
      ".cc" = "cpp";
      ".cjs" = "javascript";
      ".clj" = "clojure";
      ".cljc" = "clojure";
      ".cljs" = "clojurescript";
      ".cls" = "apex";
      ".cpp" = "cpp";
      ".cs" = "csharp";
      ".cts" = "typescript";
      ".cxx" = "cpp";
      ".dart" = "dart";
      ".ex" = "elixir";
      ".exs" = "elixir";
      ".go" = "go";
      ".h" = "c";
      ".hcl" = "hcl";
      ".hh" = "cpp";
      ".hpp" = "cpp";
      ".html" = "html";
      ".hxx" = "cpp";
      ".java" = "java";
      ".jl" = "julia";
      ".js" = "javascript";
      ".json" = "json";
      ".jsonnet" = "jsonnet";
      ".jsx" = "javascriptreact";
      ".kt" = "kotlin";
      ".kts" = "kotlin";
      ".libsonnet" = "jsonnet";
      ".lua" = "lua";
      ".mjs" = "javascript";
      ".ml" = "ocaml";
      ".mli" = "ocaml";
      ".mts" = "typescript";
      ".php" = "php";
      ".py" = "python";
      ".r" = "r";
      ".rb" = "ruby";
      ".rs" = "rust";
      ".scala" = "scala";
      ".scm" = "scheme";
      ".sh" = "shellscript";
      ".sol" = "solidity";
      ".ss" = "scheme";
      ".swift" = "swift";
      ".tf" = "terraform";
      ".trigger" = "apex";
      ".ts" = "typescript";
      ".tsx" = "typescriptreact";
      ".xml" = "xml";
      ".yaml" = "yaml";
      ".yml" = "yaml";
    };
  };

  # Claude Code - bash permissions for semgrep CLI
  programs.claude-code.settings.permissions = {
    allow = [
      # Semgrep - read-only queries
      "Bash(semgrep --version)"
      "Bash(semgrep lsp:*)"
      "Bash(semgrep scan:*)"
      "Bash(semgrep --config:*)"
    ];
    ask = [
      # Semgrep - state-changing operations
      "Bash(semgrep ci:*)"
      "Bash(semgrep login:*)"
      "Bash(semgrep publish:*)"
    ];
  };

  # OpenCode - LSP server
  programs.opencode.settings.lsp.semgrep = {
    command = [
      "${pkgs.semgrep}/bin/semgrep"
      "lsp"
    ];
    extensions = [
      ".R"
      ".bash"
      ".c"
      ".cc"
      ".cjs"
      ".clj"
      ".cljc"
      ".cljs"
      ".cls"
      ".cpp"
      ".cs"
      ".cts"
      ".cxx"
      ".dart"
      ".ex"
      ".exs"
      ".go"
      ".h"
      ".hcl"
      ".hh"
      ".hpp"
      ".html"
      ".hxx"
      ".java"
      ".jl"
      ".js"
      ".json"
      ".jsonnet"
      ".jsx"
      ".kt"
      ".kts"
      ".libsonnet"
      ".lua"
      ".mjs"
      ".ml"
      ".mli"
      ".mts"
      ".php"
      ".py"
      ".r"
      ".rb"
      ".rs"
      ".scala"
      ".scm"
      ".sh"
      ".sol"
      ".ss"
      ".swift"
      ".tf"
      ".trigger"
      ".ts"
      ".tsx"
      ".xml"
      ".yaml"
      ".yml"
    ];
  };

  # Zed Editor - LSP server and extension
  programs.zed-editor = lib.mkIf config.programs.zed-editor.enable {
    extensions = [ "semgrep" ];
    userSettings.lsp.semgrep = {
      binary = {
        path = "${pkgs.semgrep}/bin/semgrep";
        arguments = [ "lsp" ];
      };
      initialization_options = {
        scan = {
          configuration = [ "auto" ];
          only_git_dirty = false;
        };
      };
    };
  };

  # VSCode - extension and binary path
  programs.vscode = lib.mkIf config.programs.vscode.enable {
    profiles.default = {
      userSettings = {
        "semgrep.path" = "${pkgs.semgrep}/bin/semgrep";
      };
      extensions =
        with pkgs;
        [
          vscode-marketplace.semgrep.semgrep
        ];
    };
  };
}
