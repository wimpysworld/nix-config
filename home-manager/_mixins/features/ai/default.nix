{
  inputs,
  pkgs,
  ...
}:
let
  inherit (pkgs.stdenv) isLinux isDarwin;
  # https://github.com/numtide/nix-ai-tools
  aiPackagesLinux = [
    inputs.nix-ai-tools.packages.${pkgs.system}.backlog-md
    inputs.nix-ai-tools.packages.${pkgs.system}.catnip
    inputs.nix-ai-tools.packages.${pkgs.system}.claude-code
    inputs.nix-ai-tools.packages.${pkgs.system}.claudebox
    inputs.nix-ai-tools.packages.${pkgs.system}.codex
    inputs.nix-ai-tools.packages.${pkgs.system}.crush
    inputs.nix-ai-tools.packages.${pkgs.system}.gemini-cli
    inputs.nix-ai-tools.packages.${pkgs.system}.opencode
    inputs.nix-ai-tools.packages.${pkgs.system}.qwen-code
  ];
  aiPackagesDarwin = [
    pkgs.unstable.claude-code
  ];
  aiPackages =
    if isLinux then
      aiPackagesLinux
    else if isDarwin then
      aiPackagesDarwin
    else
      [ ];
in
{
  home = {
    packages = aiPackages;
  };
}
