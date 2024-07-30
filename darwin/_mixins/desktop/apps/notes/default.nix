{ lib, username, ... }:
let
  installFor = [ "martin" ];
in
lib.mkIf (lib.elem username installFor) {
  homebrew = {
    casks = [
      "heynote"
      "joplin"
    ];
  };
}
