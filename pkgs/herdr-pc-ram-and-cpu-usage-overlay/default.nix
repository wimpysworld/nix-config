{
  fetchFromGitHub,
  fontconfig,
  git,
  lib,
  makeWrapper,
  rustPlatform,
  stdenv,
}:

rustPlatform.buildRustPackage {
  pname = "herdr-pc-ram-and-cpu-usage-overlay";
  version = "1.12.0-unstable-2026-09-13";

  src = fetchFromGitHub {
    owner = "ezcorp-org";
    repo = "herdr-pc-ram-and-cpu-usage-overlay";
    rev = "9872a499181b5a52472da3f74b9c567d3898069f";
    hash = "sha256-c09LCIeKv95kSvbVtDZ2MfAoLMxVesuQD4jK5HVhzS8=";
  };

  cargoHash = "sha256-ISYzG9Tc53KMcIsrzAWshWgs8jBugy34SVT5Nqmcz/s=";

  nativeBuildInputs = [ makeWrapper ];

  postInstall = ''
    pluginRoot="$out/share/herdr/plugins/space-usage"
    install -Dm644 "$src/herdr-plugin.toml" "$pluginRoot/herdr-plugin.toml"
    mkdir -p "$pluginRoot/target/release"
    ln -s "$out/bin/space-usage" "$pluginRoot/target/release/space-usage"
  '';

  postFixup = ''
    wrapProgram "$out/bin/space-usage" \
      --prefix PATH : ${
        lib.makeBinPath ([ git ] ++ lib.optional stdenv.hostPlatform.isLinux fontconfig)
      }
  '';

  meta = {
    description = "CPU and RAM usage overlay for Herdr spaces";
    homepage = "https://github.com/ezcorp-org/herdr-pc-ram-and-cpu-usage-overlay";
    changelog = "https://github.com/ezcorp-org/herdr-pc-ram-and-cpu-usage-overlay/commits/main";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ flexiondotorg ];
    mainProgram = "space-usage";
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
}
