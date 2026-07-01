{ inputs, pkgs }:
let
  inherit (pkgs.stdenv.hostPlatform) system;
  inherit (pkgs) lib;
in
inputs.llm-agents.packages.${system}.fence.overrideAttrs (old: {
  postPatch =
    (old.postPatch or "")
    + lib.optionalString pkgs.stdenv.hostPlatform.isLinux ''
      sed -i -E 's/^[[:space:]]*linuxArgvExecMaxArgs[[:space:]]*=.*/\tlinuxArgvExecMaxArgs        = 4096/' internal/sandbox/runtime_exec_argv_linux.go
    '';
})
