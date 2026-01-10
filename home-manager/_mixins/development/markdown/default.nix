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
      marp-cli # Terminal Markdown presenter
      rumdl # Markdown linter
    ];
  };

  programs = {
    vscode = lib.mkIf config.programs.vscode.enable {
      profiles.default = {
        userSettings = {
          "emojisense.languages" = {
            plaintext = false;
            markdown = true;
            json = true;
            scminput = true;
          };
          "markdown.preview.breaks" = true;
          "rumdl.server.path" = "${pkgs.rumdl}/bin/rumdl";
        };
        extensions = with pkgs; [
          vscode-marketplace.bierner.emojisense
          vscode-marketplace.bierner.markdown-emoji
          vscode-marketplace.budparr.language-hugo-vscode
          vscode-marketplace.marp-team.marp-vscode
          vscode-marketplace.rusnasonov.vscode-hugo
          vscode-marketplace.rvben.rumdl
          vscode-marketplace.yzhang.markdown-all-in-one
        ];
      };
    };
    zed-editor = lib.mkIf config.programs.zed-editor.enable {
      extensions = [
        "emoji-completions"
        "rumdl"
      ];
    };
    neovim = lib.mkIf config.programs.neovim.enable {
      plugins = [
        (pkgs.vimPlugins.nvim-treesitter.withPlugins (p: [
          p.markdown
          p.markdown_inline
        ]))
      ];
    };
  };
}
