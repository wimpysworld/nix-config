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
  version = "1.11.1-unstable-2026-08-12";

  src = fetchFromGitHub {
    owner = "ezcorp-org";
    repo = "herdr-pc-ram-and-cpu-usage-overlay";
    rev = "fcfb6f7fa0a159adfab4528496bf10dd62e3e7c1";
    hash = "sha256-amiY6b6CQde+KQOt/B1NvYZfYLVql4xsDF5AD/qghcw=";
  };

  cargoHash = "sha256-1+GYdkc5NIOhlgleFZFTYsRilic0zAvjI78jh87DtUU=";

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
