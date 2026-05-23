{
  config,
  lib,
  pkgs,
  ...
}:
{
  home = {
    packages = with pkgs; [
      basedpyright
      python3
      python313Packages.debugpy
      ruff
      uv
    ];
  };

  claude-code.lspServers.python = {
    command = "${pkgs.basedpyright}/bin/basedpyright-langserver";
    args = [ "--stdio" ];
    extensionToLanguage = {
      ".py" = "python";
      ".pyi" = "python";
      ".pyw" = "python";
    };
  };

  fresh.settings.lsp.python = {
    command = "${pkgs.basedpyright}/bin/basedpyright-langserver";
    args = [ "--stdio" ];
    enabled = true;
    auto_start = true;
  };

  programs = {
    zed-editor = lib.mkIf config.programs.zed-editor.enable {
      extensions = [
        "python-requirements"
        "rst"
      ];
      userSettings = {
        "languages" = {
          "Python" = {
            "format_on_save" = "off";
            "formatter" = {
              "external" = {
                "command" = "${pkgs.ruff}/bin/ruff";
                "arguments" = [
                  "format"
                  "-"
                ];
              };
            };
            "language_servers" = [
              "${pkgs.basedpyright}/bin/basedpyright"
              "!ty"
            ];
          };
        };
      };
    };
    opencode = lib.mkIf config.programs.opencode.enable {
      settings = {
        formatter = {
          # Python: ruff format (requires explicit command for OpenCode)
          ruff = {
            command = [
              "${pkgs.ruff}/bin/ruff"
              "format"
              "$FILE"
            ];
            extensions = [
              ".py"
              ".pyi"
            ];
          };
        };
      };
    };
  };
}
