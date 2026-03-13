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
  version = "0.19.5";

  src = fetchFromGitHub {
    owner = "gitbutlerapp";
    repo = "gitbutler";
    tag = "release/${finalAttrs.version}";
    hash = "sha256-gVYTt4r4QlVsYewUdiHAsGeEZx2oY9wGL2RJ2JvGio4=";
  };

  cargoPatches = [
    (builtins.toFile "gitbutler-cargo-lock.patch" ''
      diff --git a/Cargo.lock b/Cargo.lock
      index f94527737..5cbcf54b5 100644
      --- a/Cargo.lock
      +++ b/Cargo.lock
      @@ -3223,15 +3223,6 @@
       [[package]]
       name = "file-id"
       version = "0.2.3"
      -source = "registry+https://github.com/rust-lang/crates.io-index"
      -checksum = "e1fc6a637b6dc58414714eddd9170ff187ecb0933d4c7024d1abbd23a3cc26e9"
      -dependencies = [
      - "windows-sys 0.60.2",
      -]
      -
      -[[package]]
      -name = "file-id"
      -version = "0.2.3"
       source = "git+https://github.com/notify-rs/notify?rev=978fe719b066a8ce76b9a9d346546b1569eecfb6#978fe719b066a8ce76b9a9d346546b1569eecfb6"
       dependencies = [
        "windows-sys 0.60.2",
      @@ -3971,7 +3962,7 @@
       version = "0.0.0"
       dependencies = [
        "deser-hjson",
      - "file-id 0.2.3 (registry+https://github.com/rust-lang/crates.io-index)",
      + "file-id 0.2.3 (git+https://github.com/notify-rs/notify?rev=978fe719b066a8ce76b9a9d346546b1569eecfb6)",
        "gitbutler-notify-debouncer",
        "mock_instant",
        "notify",
      @@ -4831,7 +4822,7 @@
       checksum = "7cb06c3e4f8eed6e24fd915fa93145e28a511f4ea0e768bae16673e05ed3f366"
       dependencies = [
        "bstr",
      - "gix-trace 0.1.18 (registry+https://github.com/rust-lang/crates.io-index)",
      + "gix-trace 0.1.18 (git+https://github.com/GitoxideLabs/gitoxide?branch=main)",
        "gix-validate 0.10.1",
        "thiserror 2.0.18",
       ]
      @@ -5080,12 +5071,6 @@
       
       [[package]]
       name = "gix-trace"
      -version = "0.1.18"
      -source = "registry+https://github.com/rust-lang/crates.io-index"
      -checksum = "f69a13643b8437d4ca6845e08143e847a36ca82903eed13303475d0ae8b162e0"
      -
      -[[package]]
      -name = "gix-trace"
       version = "0.1.18"
       source = "git+https://github.com/GitoxideLabs/gitoxide?branch=main#dad2a825d854734702e44cce8c0dfc45d7a76477"
       dependencies = [
        "tracing",
    '')
  ];

  cargoHash = "sha256-F+Ar6tnJGq+GEKTButbvou4goQbEctKHT8rQ3Z6TVd4=";

  # Let Tauri know what version we're building and deactivate the built-in updater.
  # Note: .bundle.externalBin does not include `but`, as that requires extra build changes.
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
    hash = "sha256-lOoQKtdxw7gGLcKJM2XhmWBDUSxGdxl6T/JzXmq/jo8=";
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
