{
  inputs,
  pkgs,
  platform,
  ...
}:
let
  install-anywhere = pkgs.writeShellApplication {
    name = "install-anywhere";
    runtimeInputs = with pkgs; [
      coreutils-full
      git
      tree
    ];
    text = builtins.readFile ./install-anywhere.sh;
  };
in
{
  environment.systemPackages = with pkgs; [ install-anywhere ];
}
