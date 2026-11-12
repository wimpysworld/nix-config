{
  coreutils,
  gh-api-safe,
  lib,
  python3,
  watch,
  writeShellApplication,
}:
writeShellApplication {
  name = "gh-pr-watch";
  runtimeInputs = [
    coreutils
    gh-api-safe
    python3
    watch
  ];
  text = ''
    readonly GH_PR_WATCH_SCRIPT=${lib.escapeShellArg "${./gh-pr-watch.py}"}
  ''
  + builtins.readFile ./gh-pr-watch.sh;
  checkPhase = ''
    runHook preCheck
    export PATH=${
      lib.makeBinPath [
        coreutils
        python3
        watch
      ]
    }:"$PATH"
    python3 ${./test_gh_pr_watch.py} ${./gh-pr-watch.py}
    runHook postCheck
  '';
}
