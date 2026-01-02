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
    # Packages that are used by some of the extensions below
    packages = with pkgs; [
      just
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
        "justfile"
      ];
    };
  };
}
