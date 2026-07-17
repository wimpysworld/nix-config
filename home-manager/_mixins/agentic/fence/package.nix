{ inputs, pkgs }:
inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.fence
