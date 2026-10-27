{
  config,
  lib,
  pkgs,
  ...
}:
let
  name = builtins.baseNameOf (builtins.toString ./.);
  shellApplication = pkgs.writeShellApplication {
    inherit name;
    runtimeInputs = with pkgs; [
      coreutils
      qemu_kvm
    ];
    runtimeEnv = {
      OVMF_CODE = "${pkgs.OVMF.fd}/FV/OVMF_CODE.fd";
      OVMF_VARS = "${pkgs.OVMF.fd}/FV/OVMF_VARS.fd";
    };
    text = builtins.readFile ./${name}.sh;
  };
  package = pkgs.symlinkJoin {
    inherit name;
    paths = [ shellApplication ];
    postBuild = ''
      ln -s "$out/bin/vm-runner" "$out/bin/vm-noughty"
      ln -s "$out/bin/vm-runner" "$out/bin/vm-wolfi"
    '';
  };
in
lib.mkIf config.noughty.host.is.linux {
  home.packages = [ package ];
}
