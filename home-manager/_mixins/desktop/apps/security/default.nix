{
  config,
  lib,
  pkgs,
  username,
  ...
}:
let
  inherit (pkgs.stdenv) isLinux;
  installFor = [ "martin" ];
  # Make with: pamu2fcfg -n
  u2f_vader = "G4S+zVnfPIpcnShvEuLYazwAS8XhX8DRyZZBX2OdV3K+7RVbr4UG+TqmmT3kEgC0XgTpKpN2cM/t4CpFDUE9Ig==,xxXHLkGtoMUAEbyu7/TMxmPGjuqISDVT1ldSy7qoWppWzgNlyvZZiu5bST7Llf3sHLDsT/agFbqzuf4HcVJZcw==,es256,+presence";
  u2f_thing = "Lzrc/jEJLZyBus5Cq8ufhtarA14RBs9WByxwhhWumK5lLOWu4kSn9ptkcJFlqbLldBUwMRV/JYzIKcXdPBXSaQ==,10K/2WFm1fb2ue9Bw2NxNIL2BRvab8TBYuM4J56yjo3bf1H8HB93580Ci4AY9QdaPEOK2LlqClG/exxF7L+02A==,es256,+presence";
in
lib.mkIf (isLinux && lib.elem username installFor) {
  home.packages = with pkgs; [
    _1password-gui
  ];

  xdg.configFile."Yubico/u2f_keys".text = ''
    ${username}:${u2f_vader}:${u2f_thing}
  '';
}
