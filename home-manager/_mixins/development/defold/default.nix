{
  config,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
lib.mkIf (noughtyLib.hostHasTag "gamedev") {
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
    zed-editor = lib.mkIf config.programs.zed-editor.enable {
      extensions = [
        "defold"
      ];
    };
  };
}
