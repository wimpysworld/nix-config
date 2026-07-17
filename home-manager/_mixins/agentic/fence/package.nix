{ inputs, pkgs }:
inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.fence.overrideAttrs (oldAttrs: {
  postPatch = (oldAttrs.postPatch or "") + ''
    substituteInPlace internal/sandbox/runtime_exec_deny.go \
      --replace-fail $'\t"xargs",' $'\t"xargs",\n\t// Determinate Nix exposes legacy commands as aliases of the nix binary.\n\t"nix",'
  '';
})
