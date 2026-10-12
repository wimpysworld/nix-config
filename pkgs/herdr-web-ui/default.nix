{
  autoPatchelfHook,
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
  # The prebuilt `pty.node` package that matches the host. Packages for other
  # platforms are removed.
  ptyPlatform = "${if stdenv.hostPlatform.isDarwin then "darwin" else "linux"}-${
    if stdenv.hostPlatform.isAarch64 then "arm64" else "x64"
  }";
in
stdenv.mkDerivation (finalAttrs: {
  pname = "herdr-web-ui";
  version = "0.4.7";

  src = fetchFromGitHub {
    owner = "devswha";
    repo = "herdr-web-ui";
    tag = "v${finalAttrs.version}";
    hash = "sha256-S6GHSZT+ncqgvgjnyJJpwls0rkCQ6/Pw7pKkDMdobEA=";
  };

  # nixpkgs has no Bun dependency fetcher. This fixed-output derivation runs
  # `bun install` from `bun.lock` for every platform, so one hash fits all
  # systems. `bun install` also applies the patch in `patches/`.
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

    outputHash = "sha256-J3+yDxW0mn0NUelkVidCu39jSf4mL6GqIAbrOUWRLA8=";
    outputHashAlgo = "sha256";
    outputHashMode = "recursive";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    bun
    makeBinaryWrapper
    nodejs
    writableTmpDirAsHomeHook
  ];

  # `pty.node` needs `libstdc++.so.6` and `libgcc_s.so.1`. The tree also holds
  # build-only binaries for every platform, such as esbuild, which never run
  # from the store, so only the `pty.node` package is patched.
  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [ stdenv.cc.cc.lib ];
  dontAutoPatchelf = true;
  postFixup = lib.optionalString stdenv.hostPlatform.isLinux ''
    autoPatchelf "$out/share/herdr-web-ui/node_modules/@lydell/node-pty-${ptyPlatform}"
  '';

  configurePhase = ''
    runHook preConfigure
    cp -R ${finalAttrs.node_modules}/node_modules .
    chmod -R u+w node_modules
    find node_modules/@lydell -maxdepth 1 -name 'node-pty-*' ! -name 'node-pty-${ptyPlatform}' \
      -exec rm -rf {} +
    patchShebangs node_modules
    runHook postConfigure
  '';

  buildPhase = ''
    runHook preBuild
    bun run build
    runHook postBuild
  '';

  # The server runs from this read-only tree. Its state, bridge tokens, and
  # update state go to `HERDR_WEB_STATE_DIR` (default
  # `~/.config/herdr-web-ui`), never into the tree. `server/index.ts` runs
  # without the managed supervisor, so the self-updater never starts.
  installPhase = ''
    runHook preInstall
    root="$out/share/herdr-web-ui"
    mkdir -p "$root"
    cp -R dist server shared package.json LICENSE "$root/"
    # The server imports only these packages. The install check fails when a
    # new release imports another one.
    bun ${./prune-node-modules.ts} "$root" @lydell/node-pty web-push
    makeWrapper ${lib.getExe bun} "$out/bin/herdr-web-ui" \
      --prefix PATH : ${lib.makeBinPath [ nodejs ]} \
      --chdir "$root" \
      --add-flags "$root/server/index.ts"
    runHook postInstall
  '';

  # Check that the package version matches the upstream manifest after a
  # freshener bump, and that every server import resolves in the pruned tree.
  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    grep -qx '  "version": "${finalAttrs.version}",' "$out/share/herdr-web-ui/package.json"
    test -f "$out/share/herdr-web-ui/dist/index.html"
    bun build --target=bun --outdir="$TMPDIR/bundle-check" "$out/share/herdr-web-ui/server/index.ts" >/dev/null
    runHook postInstallCheck
  '';

  meta = {
    description = "Browser and phone client for Herdr workspaces, panes, and agents";
    homepage = "https://github.com/devswha/herdr-web-ui";
    changelog = "https://github.com/devswha/herdr-web-ui/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ flexiondotorg ];
    mainProgram = "herdr-web-ui";
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
})
