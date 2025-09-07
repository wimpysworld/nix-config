{ lib, username, ... }:
let
  installFor = [
    "martin"
    "martin.wimpress"
  ];
in
lib.mkIf (lib.elem username installFor) {
  homebrew = {
    casks = [
      "heynote"
      "joplin"
    ];
  };
}
