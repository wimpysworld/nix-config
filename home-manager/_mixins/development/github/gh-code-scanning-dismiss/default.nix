{
  cacert,
  coreutils,
  gh,
  jq,
  lib,
  libiconvReal,
  runCommand,
  writeShellApplication,
  ghBackend ? runCommand "gh-code-scanning-dismiss-gh" { } ''
    mkdir -p "$out/bin"
    ln -s ${gh}/bin/.gh-wrapped "$out/bin/gh-code-scanning-dismiss-gh"
  '',
}:
writeShellApplication {
  name = "gh-code-scanning-dismiss";
  runtimeInputs = [
    coreutils
    jq
    libiconvReal
  ];
  text = ''
    readonly GH_CODE_SCANNING_DISMISS_GH=${lib.escapeShellArg "${ghBackend}/bin/gh-code-scanning-dismiss-gh"}
    readonly GH_CODE_SCANNING_DISMISS_CA_BUNDLE=${lib.escapeShellArg "${cacert}/etc/ssl/certs/ca-bundle.crt"}
  ''
  + builtins.readFile ./gh-code-scanning-dismiss.sh;
}
