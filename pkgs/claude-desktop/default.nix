{
  fetchurl,
  lib,
  makeWrapper,
  patchelf,
  stdenvNoCC,
  bintools,
  writeScript,
  copyDesktopItems,
  makeDesktopItem,

  # Linked dynamic libraries.
  alsa-lib,
  at-spi2-atk,
  at-spi2-core,
  atk,
  cairo,
  cups,
  dbus,
  expat,
  gcc-unwrapped,
  glib,
  gtk3,
  libdrm,
  libglvnd,
  libX11,
  libxcb,
  libXcomposite,
  libXdamage,
  libXext,
  libXfixes,
  libXrandr,
  libxkbcommon,
  libgbm,
  nspr,
  nss,
  pango,
  pipewire,
  wayland,

  # Provides libudev, which the main binary links directly. The libs-only
  # build avoids pulling the whole systemd closure.
  systemdLibs,

  # Loaded at runtime via dlopen.
  libsecret,
  libnotify,
  libpulseaudio,
  libayatana-appindicator,
  xdg-utils,

  # Needed for XDG_ICON_DIRS and GSETTINGS_SCHEMAS_PATH.
  adwaita-icon-theme,
  gsettings-desktop-schemas,

  # Command line arguments which are always passed to the application.
  commandLineArgs ? "",
}:

let
  pname = "claude-desktop";
  version = "1.17377.2";

  # Anthropic publish separate Debian packages per architecture.
  srcs = {
    "x86_64-linux" = {
      url = "https://downloads.claude.ai/claude-desktop/apt/stable/pool/main/c/claude-desktop/claude-desktop_${version}_amd64.deb";
      hash = "sha256-7AjUGqeYjS06P19P/fONIHtBLmYmOfQNeiZbivriEqs=";
    };
    "aarch64-linux" = {
      url = "https://downloads.claude.ai/claude-desktop/apt/stable/pool/main/c/claude-desktop/claude-desktop_${version}_arm64.deb";
      hash = "sha256-yeflb3qWvTYLgZjpVDV8c7wifht4yIp6BWVBU9ICWN0=";
    };
  };

  deps = [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    atk
    cairo
    cups
    dbus
    expat
    gcc-unwrapped.lib
    glib
    gtk3
    libayatana-appindicator
    libdrm
    libglvnd
    libgbm
    libnotify
    libpulseaudio
    libsecret
    libX11
    libxcb
    libXcomposite
    libXdamage
    libXext
    libXfixes
    libxkbcommon
    libXrandr
    nspr
    nss
    pango
    pipewire
    systemdLibs
    wayland
  ];

  # The desktop entry reproduces the one Anthropic ship in the deb. The
  # x-scheme-handler/claude MIME type registers the OAuth sign-in handler and
  # must be preserved, and the two actions expose the New chat and New Claude
  # Code session shortcuts.
  desktopItem = makeDesktopItem {
    name = "claude-desktop";
    desktopName = "Claude";
    genericName = "AI Assistant";
    comment = "Desktop application for Claude.ai";
    exec = "claude-desktop %U";
    icon = "claude-desktop";
    keywords = [
      "AI"
      "Chat"
      "Assistant"
      "Claude"
      "Code"
      "LLM"
    ];
    categories = [
      "Utility"
      "Development"
    ];
    startupNotify = true;
    startupWMClass = "claude-desktop";
    singleMainWindow = true;
    mimeTypes = [ "x-scheme-handler/claude" ];
    actions = {
      NewChat = {
        name = "New chat";
        exec = "claude-desktop claude://claude.ai/new";
      };
      NewCode = {
        name = "New Claude Code session";
        exec = "claude-desktop claude://code/new";
      };
    };
  };

  passthru = {
    category = "AI Coding Agents";

    updateScript = writeScript "update-claude-desktop.sh" ''
      #!/usr/bin/env nix-shell
      #!nix-shell -i bash -p curl gnused nix

      set -euo pipefail

      DEFAULT_NIX="$(realpath "./pkgs/claude-desktop/default.nix")"

      base="https://downloads.claude.ai/claude-desktop/apt/stable/dists/stable/main"

      # Parse the APT Packages index for one architecture and print the highest
      # version together with the SHA256 hex checksum for that version.
      latest_stanza() {
        local arch="$1"
        curl -fsSL "$base/binary-$arch/Packages" | awk '
          BEGIN { RS = ""; FS = "\n" }
          {
            ver = ""; sha = ""
            for (i = 1; i <= NF; i++) {
              if ($i ~ /^Version: /) { ver = $i; sub(/^Version: /, "", ver) }
              if ($i ~ /^SHA256: /) { sha = $i; sub(/^SHA256: /, "", sha) }
            }
            print ver " " sha
          }
        ' | sort -V | tail -n1
      }

      read -r amd64_version amd64_sha < <(latest_stanza amd64)
      read -r arm64_version arm64_sha < <(latest_stanza arm64)

      current_version="$(sed -n 's/^  version = "\(.*\)";$/\1/p' "$DEFAULT_NIX")"

      if [[ "$current_version" == "$amd64_version" ]]; then
        echo "[Nix] claude-desktop: same version"
        exit 0
      fi

      amd64_hash="$(nix-hash --to-sri --type sha256 "$amd64_sha")"
      arm64_hash="$(nix-hash --to-sri --type sha256 "$arm64_sha")"

      sed -i "s|^  version = \".*\";$|  version = \"$amd64_version\";|" "$DEFAULT_NIX"

      # Rewrite the hash on the line following each architecture URL. Matching
      # the deb suffix rather than the literal hash keeps the updater working
      # for every future release.
      sed -i "/_amd64\.deb\";$/{n;s|hash = \".*\";|hash = \"$amd64_hash\";|;}" "$DEFAULT_NIX"
      sed -i "/_arm64\.deb\";$/{n;s|hash = \".*\";|hash = \"$arm64_hash\";|;}" "$DEFAULT_NIX"
    '';
  };

  meta = with lib; {
    description = "Desktop application for Claude.ai";
    homepage = "https://claude.ai";
    # Anthropic publish no versioned changelog or release tags for Claude
    # Desktop, so this points at the canonical download and what's-new page.
    changelog = "https://claude.ai/download";
    license = licenses.unfree;
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
    maintainers = with maintainers; [ flexiondotorg ];
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    mainProgram = "claude-desktop";
  };
in
stdenvNoCC.mkDerivation {
  inherit
    pname
    version
    meta
    passthru
    ;

  src = fetchurl (
    srcs.${stdenvNoCC.hostPlatform.system}
      or (throw "Unsupported system: ${stdenvNoCC.hostPlatform.system}")
  );

  nativeBuildInputs = [
    copyDesktopItems
    makeWrapper
    patchelf
  ];

  buildInputs = [
    adwaita-icon-theme
    glib
    gsettings-desktop-schemas
    gtk3
  ];

  desktopItems = [ desktopItem ];

  unpackPhase = ''
    runHook preUnpack
    ${lib.getExe' bintools "ar"} x $src
    tar xf data.tar.xz
    runHook postUnpack
  '';

  rpath = lib.makeLibraryPath deps;

  installPhase = ''
    runHook preInstall

    # The whole Electron application ships under usr/lib; keep the upstream
    # layout so bundled libraries such as libffmpeg.so resolve next to the
    # main binary.
    mkdir -p $out/lib $out/bin $out/share
    cp -a usr/lib/claude-desktop $out/lib/claude-desktop
    cp -a usr/share/icons $out/share/icons
    cp -a usr/share/doc $out/share/doc

    # The rpath must include the application directory so ANGLE and the bundled
    # GL and Vulkan libraries can find each other and the system libGL.
    app_rpath="$rpath:$out/lib/claude-desktop"

    # Patch every dynamic ELF payload in the application tree. The interpreter
    # and rpath fail on the statically linked cowork-linux-helper and on the
    # smol-bin.x64.img disk image, so tolerate those failures.
    while IFS= read -r -d "" elf; do
      patchelf --set-interpreter ${bintools.dynamicLinker} "$elf" 2>/dev/null || true
      patchelf --set-rpath "$app_rpath" "$elf" 2>/dev/null || true
    done < <(find $out/lib/claude-desktop -type f \( -name "*.so" -o -name "*.so.*" -o -name "*.node" -o -executable \) -print0)

    # The desktop file uses bare Exec and Icon names, so copyDesktopItems
    # installs the generated item and the wrapper lands at $out/bin/claude-desktop.
    makeWrapper "$out/lib/claude-desktop/claude-desktop" "$out/bin/claude-desktop" \
      --prefix LD_LIBRARY_PATH : "$app_rpath" \
      --suffix PATH : "${lib.makeBinPath [ xdg-utils ]}" \
      --prefix XDG_DATA_DIRS : "$XDG_ICON_DIRS:$GSETTINGS_SCHEMAS_PATH" \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations --enable-wayland-ime=true}}" \
      --add-flags ${lib.escapeShellArg commandLineArgs}

    runHook postInstall
  '';
}
