{
  fetchFromGitHub,
  lib,
  makeRustPlatform,
  rust-bin,
}:
let
  # Mirrors the `rust-toolchain.toml` channel pin. It is Rust's minimum
  # supported version (MSRV), so this stays behind the package version and
  # needs a bump only when upstream raises it.
  toolchain = rust-bin.stable."1.95.0".minimal;
  rustPlatform = makeRustPlatform {
    cargo = toolchain;
    rustc = toolchain;
  };
in
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "herdr-agent-quota";

  version = "1.6.2";

  src = fetchFromGitHub {
    owner = "levi-qiao";
    repo = "herdr-agent-quota";
    tag = "v${finalAttrs.version}";
    hash = "sha256-RvbfJIVcxGCpsQMUqRkHKbUGyGu8VXanBmY5LyHnbjU=";
  };

  cargoHash = "sha256-v3C+ajqgYzkeyWQLHFv0xZlOC5RL3awc5XDWIBpLDzE=";

  # Upstream unit tests reach CLIs and the network; skip them in the sandbox.
  doCheck = false;

  postInstall = ''
    pluginRoot="$out/share/herdr/plugins/herdr-agent-quota"
    install -Dm644 "$src/herdr-plugin.toml" "$pluginRoot/herdr-plugin.toml"
    mkdir -p "$pluginRoot/target/release"
    ln -s "$out/bin/herdr-agent-quota" "$pluginRoot/target/release/herdr-agent-quota"
    cp -r "$src/assets" "$pluginRoot/assets"
  '';

  passthru.pluginDir = "herdr-agent-quota";

  meta = {
    description = "Credential-scoped AI quota and context in Herdr for Claude, Codex, Grok, Agy, OpenCode, Pi, omp, Devin, Muse, and Cursor";
    homepage = "https://github.com/levi-qiao/herdr-agent-quota";
    changelog = "https://github.com/levi-qiao/herdr-agent-quota/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ flexiondotorg ];
    mainProgram = "herdr-agent-quota";
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
})
