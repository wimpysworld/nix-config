{
  inputs,
  isWorkstation,
  lib,
  pkgs,
  ...
}:
{
  # https://github.com/numtide/nix-ai-tools
  home = {
    packages =
      with inputs.nix-ai-tools.packages.${pkgs.system};
      [
        backlog-md
        catnip
        claude-code
        claudebox
        codex
        crush
        gemini-cli
        opencode
        qwen-code
      ]
      ++ lib.optionals isWorkstation [
        claude-desktop
      ];
  };
}
