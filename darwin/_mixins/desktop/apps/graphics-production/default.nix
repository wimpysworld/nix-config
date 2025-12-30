{
  lib,
  pkgs,
  username,
  ...
}:
let
  installFor = [
    "none"
  ];
in
lib.mkIf (lib.elem username installFor) {
  environment.systemPackages = with pkgs; [
    inkscape
    pika
  ];
}
