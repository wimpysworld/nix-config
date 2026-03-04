{
  lib,
  stdenv,
  cacert,
  cargo-tauri,
  cmake,
  curl,
  desktop-file-utils,
  fetchFromGitHub,
  git,
  glib-networking,
  jq,
  libgit2,
  makeBinaryWrapper,
  moreutils,
  nodejs,
  openssl,
  pkg-config,
  fetchPnpmDeps,
  pnpmConfigHook,
  pnpm,
  rust,
  rustPlatform,
  turbo,
  webkitgtk_4_1,
  wrapGAppsHook4,
  dart-sass,
}:
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "gitbutler";
  version = "0.19.3";

  src = fetchFromGitHub {
    owner = "gitbutlerapp";
    repo = "gitbutler";
    tag = "release/${finalAttrs.version}";
    hash = "sha256-OEDTpCtnIOTGxz6c3BoA9yVjaOHVemizIUtDuPuLc8A=";
  };

  cargoDeps = rustPlatform.fetchCargoVendor {
    inherit (finalAttrs)
      pname
      version
      src
      ;
    hash = "sha256-ljfTJWQfwoVSh/LMrW6VFVN9ViFfM3iH2sEze3f5C+M=";
    postPatch = ''
      substituteInPlace Cargo.lock \
        --replace-fail '"file-id 0.2.3 (registry+https://github.com/rust-lang/crates.io-index)",' '"file-id 0.2.3 (git+https://github.com/notify-rs/notify?rev=978fe719b066a8ce76b9a9d346546b1569eecfb6)",'

      substituteInPlace Cargo.lock \
        --replace-fail $'[[package]]\nname = "file-id"\nversion = "0.2.3"\nsource = "registry+https://github.com/rust-lang/crates.io-index"\nchecksum = "e1fc6a637b6dc58414714eddd9170ff187ecb0933d4c7024d1abbd23a3cc26e9"\ndependencies = [\n "windows-sys 0.60.2",\n]\n\n' ""
    '';
  };

  # Let Tauri know what version we're building and deactivate the built-in updater.
  # Note: .bundle.externalBin does not include `but`, as that requires extra build changes.
  prePatch = ''
    substituteInPlace Cargo.lock \
      --replace-fail '"file-id 0.2.3 (registry+https://github.com/rust-lang/crates.io-index)",' '"file-id 0.2.3 (git+https://github.com/notify-rs/notify?rev=978fe719b066a8ce76b9a9d346546b1569eecfb6)",'

    substituteInPlace Cargo.lock \
      --replace-fail $'[[package]]\nname = "file-id"\nversion = "0.2.3"\nsource = "registry+https://github.com/rust-lang/crates.io-index"\nchecksum = "e1fc6a637b6dc58414714eddd9170ff187ecb0933d4c7024d1abbd23a3cc26e9"\ndependencies = [\n "windows-sys 0.60.2",\n]\n\n' ""
  '';

  postPatch = ''
    tauriConfRelease="crates/gitbutler-tauri/tauri.conf.release.json"
    jq '.
        | (.version = "${finalAttrs.version}")
        | (.bundle.createUpdaterArtifacts = false)
        | (.bundle.externalBin = ["gitbutler-git-setsid", "gitbutler-git-askpass"])
      ' "$tauriConfRelease" | sponge "$tauriConfRelease"

    substituteInPlace apps/desktop/src/lib/backend/tauri.ts \
      --replace-fail 'checkUpdate = tauriCheck;' 'checkUpdate = () => null;'
  '';

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs)
      pname
      version
      src
      ;
    fetcherVersion = 2;
    hash = "sha256-ZhykVbbATjMoj6EYGlbrJ5C5nQ3l4tqWZeaH+vOdxdY=";
  };

  nativeBuildInputs = [
    cacert # Required by turbo.
    cargo-tauri.hook
    cmake # Required by `zlib-sys` crate.
    desktop-file-utils
    jq
    moreutils
    nodejs
    pkg-config
    pnpmConfigHook
    pnpm
    turbo
    wrapGAppsHook4
    dart-sass
  ]
  ++ lib.optional stdenv.hostPlatform.isDarwin makeBinaryWrapper;

  buildInputs = [
    libgit2
    openssl
  ]
  ++ lib.optional stdenv.hostPlatform.isDarwin curl
  ++ lib.optionals stdenv.hostPlatform.isLinux [
    glib-networking
    webkitgtk_4_1
  ];

  tauriBuildFlags = [
    "--config"
    "crates/gitbutler-tauri/tauri.conf.release.json"
  ];

  nativeCheckInputs = [ git ];

  cargoTestFlags = [
    "--workspace"
  ]
  ++ lib.concatMap (crate: [ "--exclude=${crate}" ]) [
    # Requires Git directories.
    "but-core"
    "but-rebase"
    "but-workspace"
    # Fails due to the issues above and below.
    "but-hunk-dependency"
    # Assumes a debug build and fixed crate location.
    "gitbutler-branch-actions"
    "gitbutler-stack"
    "gitbutler-edit-mode"
    "but-cherry-apply"
    "but-worktrees"
  ]
  ++ [
    "--"
  ]
  ++ lib.concatMap (test: [ "--skip=${test}" ]) [
    "test_is_network_error"
    "git_editor_takes_precedence"
    "migrations_in_parallel_with_processes"
    "merge_first_branch_into_gb_local_and_verify_rebase"
    "json_output_with_dangling_commits"
    "two_dangling_commits_different_branches"
    "track_directory_changes_after_rename"
  ];

  env = {
    # Make sure `inject-git-binaries.sh` can find our target directory.
    TRIPLE_OVERRIDE = rust.envVars.rustHostPlatformSpec;

    # fetchPnpmDeps and pnpmConfigHook use a specific pnpm version, not upstream's.
    COREPACK_ENABLE_STRICT = 0;

    # Task tracing requires Tokio to be built with this flag.
    RUSTFLAGS = "--cfg tokio_unstable";

    TURBO_BINARY_PATH = lib.getExe turbo;
    TURBO_TELEMETRY_DISABLED = 1;

    OPENSSL_NO_VENDOR = true;
    LIBGIT2_NO_VENDOR = 1;
  };

  preBuild = ''
    # Force the sass npm dependency to use our own sass binary instead of the bundled one.
    substituteInPlace node_modules/.pnpm/sass-embedded@*/node_modules/sass-embedded/dist/lib/src/compiler-path.js \
      --replace-fail 'compilerCommand = (() => {' 'compilerCommand = (() => { return ["${lib.getExe dart-sass}"];'

    turbo run --filter @gitbutler/svelte-comment-injector build
    pnpm build:desktop -- --mode production
  '';

  postInstall =
    lib.optionalString stdenv.hostPlatform.isDarwin ''
      makeBinaryWrapper $out/Applications/GitButler.app/Contents/MacOS/gitbutler-tauri $out/bin/gitbutler-tauri
    ''
    + lib.optionalString stdenv.hostPlatform.isLinux ''
      desktop-file-edit \
        --set-comment "A Git client for simultaneous branches on top of your existing workflow." \
        --set-key="Keywords" --set-value="git;" \
        --set-key="StartupWMClass" --set-value="GitButler" \
        $out/share/applications/GitButler.desktop
    '';

  meta = {
    description = "Git client for simultaneous branches on top of your existing workflow";
    homepage = "https://gitbutler.com";
    changelog = "https://github.com/gitbutlerapp/gitbutler/releases/tag/release/${finalAttrs.version}";
    license = lib.licenses.fsl11Mit;
    maintainers = with lib.maintainers; [ flexiondotorg ];
    mainProgram = "gitbutler-tauri";
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
})
