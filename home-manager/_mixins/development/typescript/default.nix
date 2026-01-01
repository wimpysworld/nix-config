{
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
      tsx
      typescript
      typescript-language-server
      vscode-js-debug
      vtsls
    ];
  };
}
