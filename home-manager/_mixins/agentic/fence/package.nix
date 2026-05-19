{ inputs, pkgs }:
let
  inherit (pkgs.stdenv.hostPlatform) system;
in
inputs.llm-agents.packages.${system}.fence.overrideAttrs (old: {
  postPatch = (old.postPatch or "") + ''
    sed -i -E 's/^[[:space:]]*linuxArgvExecMaxArgs[[:space:]]*=.*/\tlinuxArgvExecMaxArgs        = 4096/' internal/sandbox/runtime_exec_argv_linux.go
  '';
})
