{
  lib,
  fetchFromGitHub,
  makeWrapper,
  nasm,
  procps,
  rustPlatform,
  stdenv,
  xdg-utils,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "ai-usagebar";
  version = "1.41.0";

  src = fetchFromGitHub {
    owner = "akitaonrails";
    repo = "ai-usagebar";
    tag = "v${finalAttrs.version}";
    hash = "sha256-mS5K/IntyuDEsFmsMWtKYhjsS3T3qeRAYsTqS1TsZxA=";
  };

  cargoHash = "sha256-VV7If1vQFufyFHK6C+K9LADLU90FsD7gOGcvSJ4U3wo=";

  # `claude_desktop::app` runs `/usr/bin/tar`, which the build sandbox does not
  # have. Upstream `nix/package.nix` skips the same tests.
  checkFlags = [ "--skip=claude_desktop::app::tests" ];

  nativeBuildInputs =
    lib.optionals stdenv.hostPlatform.isx86_64 [ nasm ]
    ++ lib.optionals stdenv.hostPlatform.isLinux [ makeWrapper ];

  # The tray binary is a stub on Linux, and only the macOS and Windows tray
  # hosts run the release update check, so the package ships neither. `pkill`
  # signals Waybar after a vendor cycle.
  postInstall = ''
    rm -f "$out/bin/ai-usagebar-tray"
    install -Dm644 config.example.toml "$out/share/ai-usagebar/config.example.toml"
  ''
  + lib.optionalString stdenv.hostPlatform.isLinux ''
    for program in ai-usagebar ai-usagebar-tui; do
      wrapProgram "$out/bin/$program" \
        --prefix PATH : ${
          lib.makeBinPath [
            procps
            xdg-utils
          ]
        }
    done
  '';

  meta = {
    description = "Waybar widget and TUI that show AI plan usage for several providers";
    homepage = "https://github.com/akitaonrails/ai-usagebar";
    changelog = "https://github.com/akitaonrails/ai-usagebar/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ flexiondotorg ];
    mainProgram = "ai-usagebar";
    platforms = lib.platforms.linux;
  };
})
