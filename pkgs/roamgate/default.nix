{
  bun,
  fetchFromGitHub,
  lib,
  makeBinaryWrapper,
  nodejs,
  stdenv,
  stdenvNoCC,
  writableTmpDirAsHomeHook,
}:
let
  # `@earendil-works/chord` depends on esbuild, which lists a binary package
  # for every platform. Only the package that matches the host stays.
  esbuildPlatform = "${if stdenv.hostPlatform.isDarwin then "darwin" else "linux"}-${
    if stdenv.hostPlatform.isAarch64 then "arm64" else "x64"
  }";
in
stdenv.mkDerivation (finalAttrs: {
  pname = "roamgate";
  version = "0.8.2";

  src = fetchFromGitHub {
    owner = "powerfooI";
    repo = "roamgate";
    tag = "v${finalAttrs.version}";
    hash = "sha256-5zqNjEqTr5w78HH4xvTkWVLXMr8o3cHL9CNDKxx/4UI=";
  };

  # nixpkgs has no Bun dependency fetcher. This fixed-output derivation runs
  # `bun install` from `bun.lock` for every platform, so one hash fits all
  # systems. The hoisted linker gives a flat tree without `.bun` symlinks, so
  # the prune step can copy packages as they are.
  node_modules = stdenvNoCC.mkDerivation {
    pname = "${finalAttrs.pname}-node_modules";
    inherit (finalAttrs) version src;

    impureEnvVars = lib.fetchers.proxyImpureEnvVars ++ [
      "GIT_PROXY_COMMAND"
      "SOCKS_SERVER"
    ];

    nativeBuildInputs = [
      bun
      writableTmpDirAsHomeHook
    ];

    dontConfigure = true;

    buildPhase = ''
      runHook preBuild
      export BUN_INSTALL_CACHE_DIR=$(mktemp -d)
      bun install \
        --cpu="*" \
        --frozen-lockfile \
        --ignore-scripts \
        --linker=hoisted \
        --no-progress \
        --os="*"
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp -R node_modules $out/
      runHook postInstall
    '';

    # A fixed-output derivation must not reference store paths.
    dontFixup = true;

    outputHash = "sha256-hbxrcN4Rk1kWTuCEJBpBqhb01Q8HlQOT8iV30ZnVJMI=";
    outputHashAlgo = "sha256";
    outputHashMode = "recursive";
  };

  nativeBuildInputs = [
    bun
    makeBinaryWrapper
    nodejs
    writableTmpDirAsHomeHook
  ];

  # Upstream runs repository worktree hooks (`roamgate.json`, `paseo.json`)
  # unless a repository turns them off. Turn the default off for every
  # repository, so a hook runs only after the user enables it for that
  # repository in the Roamgate settings. `--replace-fail` stops the build when
  # a release changes these lines.
  postPatch = ''
    substituteInPlace server/src/config/gui-settings.ts \
      --replace-fail 'if (!repoKey) return true;' 'if (!repoKey) return false;' \
      --replace-fail 'settings.repositories[repoKey]?.worktree_hooks_enabled !== false' \
        'settings.repositories[repoKey]?.worktree_hooks_enabled === true'
    substituteInPlace server/src/workspace/status.ts \
      --replace-fail 'settings.repositories[key]?.worktree_hooks_enabled !== false' \
        'settings.repositories[key]?.worktree_hooks_enabled === true'
  '';

  configurePhase = ''
    runHook preConfigure
    cp -R ${finalAttrs.node_modules}/node_modules .
    chmod -R u+w node_modules
    patchShebangs node_modules
    runHook postConfigure
  '';

  buildPhase = ''
    runHook preBuild
    bun run build:web
    runHook postBuild
  '';

  # The server runs from source on Bun, not as the `bun build --compile`
  # binary, so the self-updater cannot replace it. It reads this tree only.
  # Its token, session secret, settings, and uploads go to
  # `~/.config/roamgate`. The server imports the PWA manifest from
  # `web/public`, so that file stays.
  installPhase = ''
    runHook preInstall
    root="$out/share/roamgate"
    mkdir -p "$root/server" "$root/web/public"
    cp -R server/src server/public server/package.json "$root/server/"
    cp -R shared package.json LICENSE "$root/"
    cp web/public/manifest.json "$root/web/public/"
    # The server imports only these packages. The install check fails when a
    # new release imports another one.
    bun ${./prune-node-modules.ts} "$root" \
      @earendil-works/chord \
      @earendil-works/pi-ai \
      @earendil-works/pi-coding-agent \
      @earendil-works/pi-durable \
      proper-lockfile \
      typebox \
      undici \
      web-push
    find "$root/node_modules/@esbuild" -mindepth 1 -maxdepth 1 ! -name '${esbuildPlatform}' \
      -exec rm -rf {} +
    makeWrapper ${lib.getExe bun} "$out/bin/roamgate" \
      --prefix PATH : ${lib.makeBinPath [ nodejs ]} \
      --chdir "$root" \
      --set PUBLIC_DIR "$root/server/public" \
      --add-flags "$root/server/src/index.ts"
    runHook postInstall
  '';

  # Check that the package version matches the upstream manifest after a
  # freshener bump, and that every server import resolves in the pruned tree.
  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    grep -qx '  "version": "${finalAttrs.version}",' "$out/share/roamgate/package.json"
    test -f "$out/share/roamgate/server/public/index.html"
    bun build --target=bun --outdir="$TMPDIR/bundle-check" "$out/share/roamgate/server/src/index.ts" >/dev/null
    runHook postInstallCheck
  '';

  meta = {
    description = "Web and phone client for Herdr workspaces, panes, agents, and worktrees";
    homepage = "https://github.com/powerfooI/roamgate";
    changelog = "https://github.com/powerfooI/roamgate/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ flexiondotorg ];
    mainProgram = "roamgate";
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
})
