{
  bash,
  coreutils,
  gh,
  lib,
  runCommand,
  shellcheck-minimal,
  writeShellApplication,
  ghBackend ? runCommand "gh-notification-dismiss-gh" { } ''
    mkdir -p "$out/bin"
    ln -s ${gh}/bin/.gh-wrapped "$out/bin/gh-notification-dismiss-gh"
  '',
}:
writeShellApplication {
  name = "gh-notification-dismiss";
  runtimeInputs = [
    coreutils
  ];
  text = ''
    : "''${GH_NOTIFICATION_DISMISS_GH_BIN:=${ghBackend}/bin/gh-notification-dismiss-gh}"
  ''
  + builtins.readFile ./gh-notification-dismiss.sh;
  derivationArgs = {
    postCheck =
      lib.optionalString shellcheck-minimal.compiler.bootstrapAvailable ''
        ${lib.getExe shellcheck-minimal} ${./gh-notification-dismiss-tests.sh}
      ''
      + ''
        ${lib.getExe bash} ${./gh-notification-dismiss-tests.sh} "$target"
      '';
  };
}
