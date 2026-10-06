{
  lib,
  writeShellApplication,
  coreutils,
  flock,
  upstream,
  lockDir,
}:
writeShellApplication {
  name = "sops-install-secrets";
  runtimeInputs = [ coreutils ];
  text = lib.replaceStrings [ "@upstream@" "@flock@" "@lockDir@" ] (map lib.escapeShellArg [
    "${upstream}/bin/sops-install-secrets"
    "${flock}/bin/flock"
    lockDir
  ]) (builtins.readFile ./sops-install-secrets.sh);
}
