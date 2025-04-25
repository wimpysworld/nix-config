{
  lib,
  stdenv,
  fetchFromGitHub,
  makeWrapper, # Needed for both Linux and Darwin now
  copyDesktopItems,
  electron_34,
  nodejs,
  pnpm_9,
  makeDesktopItem,
  darwin,
  nix-update-script,
}:

let
  electron = electron_34;
in
stdenv.mkDerivation (finalAttrs: {
  pname = "podman-desktop";
  version = "1.18.0";

  passthru.updateScript = nix-update-script { };

  src = fetchFromGitHub {
    owner = "containers";
    repo = "podman-desktop";
    tag = "v${finalAttrs.version}";
    hash = "sha256-u3Irn+hSyTNTLl8QenMZbISE5aFhb58mOSOooVoijKw="; # Keep original hash
  };

  # NOTE: You might need to update this hash if the upstream dependencies changed
  # significantly for Darwin support, though often they don't.
  # Re-run the build once, let it fail on the hash mismatch, and copy the expected hash.
  pnpmDeps = pnpm_9.fetchDeps {
    inherit (finalAttrs) pname version src;
    hash = "sha256-2k0BbE9FkWEErsTuCECjy+iI3u1Biv1MF9hI7Oq3Aus="; # Keep original hash
  };

  patches = [
    # podman should be installed with nix; disable auto-installation
    ./extension-no-download-podman.patch
  ];

  ELECTRON_SKIP_BINARY_DOWNLOAD = "1";

  # Don't attempt to sign the darwin app bundle.
  # It's impure and may fail in some restricted environments.
  CSC_IDENTITY_AUTO_DISCOVERY = lib.optionals stdenv.isDarwin "false";

  nativeBuildInputs = [
    nodejs
    pnpm_9.configHook
    makeWrapper # Now needed unconditionally for the bin wrapper
  ] ++ lib.optionals (!stdenv.isDarwin) [
    copyDesktopItems # Only needed for Linux .desktop files
  ] ++ lib.optionals stdenv.isDarwin [
    darwin.autoSignDarwinBinariesHook
  ];

  buildPhase = ''
    runHook preBuild

    # Use the Electron distribution provided by Nixpkgs
    cp -r ${electron.dist} electron-dist
    chmod -R u+w electron-dist # Ensure we can write to it if needed

    # Run the build command specified by podman-desktop
    pnpm build

    # Run electron-builder to package the application
    # We point it to our Nixpkgs electron distribution
    ./node_modules/.bin/electron-builder \
      --dir \
      --config .electron-builder.config.cjs \
      -c.electronDist=electron-dist \
      -c.electronVersion=${electron.version} \
      ${lib.optionalString stdenv.isDarwin "--macos"} \
      ${lib.optionalString stdenv.isLinux "--linux"}

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    ${lib.optionalString stdenv.isDarwin ''
      # Create the Applications directory and move the built .app bundle
      mkdir -p $out/Applications
      mv dist/mac*/Podman\ Desktop.app $out/Applications/

      # Create a bin wrapper script to launch the app from the command line
      makeWrapper "${stdenv.shell}" "$out/bin/podman-desktop" \
        --add-flags "-c" \
        --add-flags "open -a \\\"$out/Applications/Podman Desktop.app\\\" --args \\\"\$@\\\"" \
        --inherit-argv0
    ''}

    ${lib.optionalString (!stdenv.isDarwin) ''
      # Standard Linux installation: copy resources and create a wrapper
      mkdir -p "$out/share/lib/podman-desktop"
      cp -r dist/*-unpacked/{locales,resources{,.pak}} "$out/share/lib/podman-desktop"

      install -Dm644 buildResources/icon.svg "$out/share/icons/hicolor/scalable/apps/podman-desktop.svg"

      makeWrapper '${electron}/bin/electron' "$out/bin/podman-desktop" \
        --add-flags "$out/share/lib/podman-desktop/resources/app.asar" \
        --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations --enable-wayland-ime=true}}" \
        --inherit-argv0
    ''}

    runHook postInstall
  '';

  # .desktop files are primarily a Linux concept
  desktopItems = lib.optionals (!stdenv.isDarwin) [
    (makeDesktopItem {
      name = "podman-desktop";
      exec = "podman-desktop %U";
      icon = "podman-desktop";
      desktopName = "Podman Desktop";
      genericName = "Desktop client for podman";
      comment = finalAttrs.meta.description;
      categories = [ "Utility" ];
      startupWMClass = "Podman Desktop";
    })
  ];

  meta = {
    description = "A graphical tool for developing on containers and Kubernetes";
    homepage = "https://podman-desktop.io";
    changelog = "https://github.com/containers/podman-desktop/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.asl20;
    maintainers = with lib.maintainers; [
      booxter
      panda2134
    ];
    # Inheriting platforms from electron is usually fine, but let's be explicit
    # Assumes electron_34 supports these. Check `nix repl` -> `<nixpkgs>.electron_34.meta.platforms` if unsure.
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
    mainProgram = "podman-desktop";
  };
})