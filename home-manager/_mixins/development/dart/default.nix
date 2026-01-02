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
      dart
    ];
  };

  programs = {
    vscode = lib.mkIf config.programs.vscode.enable {
      profiles.default = {
        userSettings = {
          "dart.updateDevTools" = false;
          "dart.checkForSdkUpdates" = false;
          "[dart]"."editor.formatOnSave" = true;
          "[dart]"."editor.formatOnType" = true;
          "[dart]"."editor.rulers" = [ 80 ];
          "[dart]"."editor.selectionHighlight" = false;
          "[dart]"."editor.suggest.snippetsPreventQuickSuggestions" = false;
          "[dart]"."editor.suggestSelection" = "first";
          "[dart]"."editor.tabCompletion" = "onlySnippets";
          "[dart]"."editor.wordBasedSuggestions" = "off";
        };
        extensions = with pkgs; [
          vscode-marketplace.dart-code.dart-code
          vscode-marketplace.dart-code.flutter
          vscode-marketplace.jeroen-meijer.pubspec-assist
        ];
      };
    };
    zed-editor = lib.mkIf config.programs.zed-editor.enable {
      extensions = [
        "dart"
      ];
    };
  };
}
