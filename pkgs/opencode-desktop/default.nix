{
  lib,
  stdenvNoCC,
  fetchurl,
  bintools,
  patchelf,
  makeWrapper,
  wrapGAppsHook3,
  webkitgtk_4_1,
  gtk3,
  glib,
  cairo,
  gdk-pixbuf,
  libsoup_3,
  openssl,
}:
let
  pname = "opencode-desktop";
  version = "1.2.15";

  sources = {
    x86_64-linux = fetchurl {
      url = "https://github.com/anomalyco/opencode/releases/download/v${version}/opencode-desktop-linux-amd64.deb";
      hash = "sha256-TJmFT+ZUtnb3O7LG2xrJJKJBt+VNkTs4jk45j8mnHPE=";
    };
    aarch64-linux = fetchurl {
      url = "https://github.com/anomalyco/opencode/releases/download/v${version}/opencode-desktop-linux-arm64.deb";
      hash = "sha256-wlEfUjNASbo0xkC4gfwTwmWghkv1rEahKvOLhWJUL2c=";
    };
    aarch64-darwin = fetchurl {
      url = "https://github.com/anomalyco/opencode/releases/download/v${version}/opencode-desktop-darwin-aarch64.app.tar.gz";
      hash = "sha256-dWM7gFBeO7S9quefSsK7fElIn2ewTFeIGAXh2Hvm1dA=";
    };
  };

  # Shared library search path for the Tauri (WebKitGTK) desktop binary.
  rpath = lib.makeLibraryPath [
    webkitgtk_4_1
    gtk3
    glib
    cairo
    gdk-pixbuf
    libsoup_3
    openssl
  ];

  # Linux package: unpack .deb and patch ELF binaries.
  linux = stdenvNoCC.mkDerivation {
    inherit
      pname
      version
      meta
      passthru
      ;

    src = sources.${stdenvNoCC.hostPlatform.system};

    # Stripping and autoPatchelf are both disabled because opencode-cli is a
    # Bun-compiled binary with JavaScript appended after the ELF sections.
    # strip truncates the payload; patchelf section rewriting can corrupt it.
    # We patch only the Tauri binary (OpenCode) manually in postFixup.
    dontStrip = true;
    dontPatchELF = true;

    nativeBuildInputs = [
      patchelf
      makeWrapper
      wrapGAppsHook3
      bintools
    ];

    buildInputs = [
      gtk3
      glib
    ];

    unpackPhase = ''
      runHook preUnpack
      ar x "$src"
      tar xzf data.tar.gz
      runHook postUnpack
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p "$out/bin"
      mkdir -p "$out/share"

      # Install the main Tauri desktop binary.
      install -Dm755 usr/bin/OpenCode "$out/lib/opencode-desktop/OpenCode"

      # Install the CLI companion verbatim; it is a Bun-compiled binary with
      # JavaScript appended after the ELF data. It must not be stripped or
      # patched, so we copy it as-is and only patch the Tauri binary below.
      cp usr/bin/opencode-cli "$out/lib/opencode-desktop/opencode-cli"
      chmod 755 "$out/lib/opencode-desktop/opencode-cli"

      # Desktop integration files shipped in the .deb.
      cp -r usr/share/icons "$out/share/"
      cp -r usr/share/applications "$out/share/"
      cp -r usr/share/metainfo "$out/share/" 2>/dev/null || true

      # Fix the desktop file to point at our wrapper.
      substituteInPlace "$out/share/applications/OpenCode.desktop" \
        --replace-fail "Exec=OpenCode" "Exec=opencode-desktop"

      # Wrapper for the GUI binary with Wayland support.
      makeWrapper "$out/lib/opencode-desktop/OpenCode" "$out/bin/opencode-desktop" \
        --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto}}"

      # Expose the CLI as well.
      ln -s "$out/lib/opencode-desktop/opencode-cli" "$out/bin/opencode-cli"

      runHook postInstall
    '';

    # Patch the Tauri binary's ELF interpreter and RPATH so it finds
    # WebKitGTK, GTK3, libsoup and friends at runtime.
    postFixup = ''
      patchelf \
        --set-interpreter "$(cat ${bintools}/nix-support/dynamic-linker)" \
        --set-rpath "${rpath}" \
        "$out/lib/opencode-desktop/OpenCode"
    '';
  };

  # macOS package: unpack the .app.tar.gz archive.
  darwin = stdenvNoCC.mkDerivation {
    inherit
      pname
      version
      meta
      passthru
      ;

    src = sources.aarch64-darwin;

    dontPatch = true;
    dontConfigure = true;
    dontBuild = true;
    dontFixup = true;

    nativeBuildInputs = [ makeWrapper ];

    sourceRoot = ".";

    installPhase = ''
      runHook preInstall

      mkdir -p "$out/Applications" "$out/bin"
      cp -r OpenCode.app "$out/Applications/"

      # Convenience wrapper so the binary is on PATH.
      makeWrapper "$out/Applications/OpenCode.app/Contents/MacOS/OpenCode" "$out/bin/opencode-desktop"

      # Expose the CLI companion.
      ln -s "$out/Applications/OpenCode.app/Contents/MacOS/opencode-cli" "$out/bin/opencode-cli"

      runHook postInstall
    '';
  };

  passthru = { };

  meta = {
    description = "OpenCode desktop client - an open source AI coding agent";
    homepage = "https://opencode.ai";
    changelog = "https://github.com/anomalyco/opencode/releases/tag/v${version}";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ flexiondotorg ];
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "aarch64-darwin"
    ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    mainProgram = "opencode-desktop";
  };
in
if stdenvNoCC.hostPlatform.isDarwin then
  darwin
else if stdenvNoCC.hostPlatform.isLinux then
  linux
else
  throw "Unsupported platform ${stdenvNoCC.hostPlatform.system}"
