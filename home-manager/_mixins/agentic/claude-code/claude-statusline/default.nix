{
  ccstatuslinePackage,
  herdrAgentUsagePackage,
  pkgs,
}:

pkgs.writeShellApplication {
  name = "claude-statusline";
  runtimeInputs = [
    ccstatuslinePackage
    herdrAgentUsagePackage
  ];
  text = builtins.readFile ./claude-statusline.sh;
}
