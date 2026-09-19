{
  ccstatuslinePackage,
  pkgs,
}:

pkgs.writeShellApplication {
  name = "claude-statusline";
  runtimeInputs = [
    ccstatuslinePackage
  ];
  text = builtins.readFile ./claude-statusline.sh;
}
