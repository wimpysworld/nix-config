{
  config,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
lib.mkIf (noughtyLib.isUser [ "martin" ]) {
  home = {
    # Packages that are used by some of the extensions below
    packages = with pkgs; [
      just
      just-formatter
      just-lsp
    ];
  };

  programs = {
    vscode = lib.mkIf config.programs.vscode.enable {
      profiles.default = {
        extensions = with pkgs; [
          vscode-marketplace.nefrob.vscode-just-syntax
          vscode-marketplace.tobiashochguertel.just-formatter
        ];
      };
    };
    zed-editor = lib.mkIf config.programs.zed-editor.enable {
      extensions = [
        "just"
        "just-ls"
      ];
      userSettings = {
        languages = {
          Just = {
            formatter = {
              external = {
                command = "${pkgs.just-formatter}/bin/just-formatter";
              };
            };
            language_servers = [
              "just-lsp"
            ];
          };
        };
        lsp = {
          just-lsp = { };
        };
      };
    };
    neovim = lib.mkIf config.programs.neovim.enable {
      plugins = [
        (pkgs.vimPlugins.nvim-treesitter.withPlugins (p: [
          p.just
        ]))
      ];
    };
  };
}
