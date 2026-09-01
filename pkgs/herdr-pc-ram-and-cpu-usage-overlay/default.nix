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
  version = "1.11.2-unstable-2026-08-27";

  src = fetchFromGitHub {
    owner = "ezcorp-org";
    repo = "herdr-pc-ram-and-cpu-usage-overlay";
    rev = "94a2ea3bf21ec35c6da51b9657c97167e68034ce";
    hash = "sha256-WN8AnkybU57ZfN+Qd86ajBHgxMGScOeu6BUD7ARlMRg=";
  };

  cargoHash = "sha256-+hm0h/VXXZzSt8jpIjK3Ygm86yIXEEo4DcULCMDRc+M=";

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
