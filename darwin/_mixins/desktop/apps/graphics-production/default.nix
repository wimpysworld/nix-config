{
  lib,
  pkgs,
  username,
  ...
}:
let
  installFor = [
    "martin"
    "martin.wimpress"
  ];
in
lib.mkIf (lib.elem username installFor) {
  environment.systemPackages = with pkgs; [
    inkscape
    pika
  ];
}
