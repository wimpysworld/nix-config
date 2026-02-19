{
  config,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
lib.mkIf
  (noughtyLib.isHost [
    "phasma"
    "vader"
  ])
  {
    home = {
      packages = with pkgs; [
        defold-bob
        (defold.override {
          uiScale = "1.25";
        })
      ];
      sessionVariables = {
        BOB_JAR = "${pkgs.defold-bob}/bob.jar";
      };
    };
    programs = {
      vscode = lib.mkIf config.programs.vscode.enable {
        profiles.default = {
          extensions = with pkgs; [
            vscode-marketplace.astronachos.defold
          ];
        };
      };
      zed-editor = lib.mkIf config.programs.zed-editor.enable {
        extensions = [
          "defold"
        ];
      };
    };
  }
