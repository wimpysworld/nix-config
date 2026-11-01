# Build Moltis from the flexiondotorg/moltis fork commit that adds
# private_instance support for Matrix accounts, while carrying forward the
# prebuilt web and WASM runtime assets from the matching 20261023.01 release
# archive under share/moltis.
{
  lib,
  fetchFromGitHub,
  fetchurl,
  rustPlatform,
  cmake,
  perl,
  pkg-config,
  makeWrapper,
}:

let
  version = "20261023.01";
  rev = "8d3415a6f8b1462192dc39c2ef94bee3efacb45c";

  src = fetchFromGitHub {
    owner = "flexiondotorg";
    repo = "moltis";
    inherit rev;
    hash = "sha256-5/LZtgM9mYCDY6lerA9c3Fn6aNssOpaoV7nGmCYubEs=";
  };

  releaseArchive = fetchurl {
    url = "https://github.com/moltis-org/moltis/releases/download/${version}/moltis-${version}-x86_64-unknown-linux-gnu.tar.gz";
    hash = "sha256-kDjdhkbZ3bItq+U7nRsWQ5vT9MVNgXuKyuYwnJEQ3CQ=";
  };
in
rustPlatform.buildRustPackage {
  pname = "moltis";
  inherit version src;

  cargoLock = {
    lockFile = "${src}/Cargo.lock";
    outputHashes = {
      "sqlx-core-0.8.6" = "sha256-iZZlJ8YGlM1YUEGitK4aZH68tmg3y+gAVysXS8B+DW8=";
      "wacore-0.6.0" = "sha256-gjb3Lt0hMF5unxT8xTYX282wxi4aik7Vx0blxYzGF4w=";
      "zvec-rust-0.6.0" = "sha256-10JztaOrXQ7yPABMf5rYB3gTelWsYtclnLBW3O29Gns=";
    };
  };

  buildNoDefaultFeatures = true;
  buildFeatures = [
    "acp"
    "agent"
    "bundled-skills"
    "caldav"
    "claude-import"
    "cloudflare-tunnel"
    "code-index-builtin"
    "code-splitter"
    "codex-import"
    "connectors"
    "discord"
    "file-watcher"
    "firecrawl"
    "fs-tools"
    "graphql"
    "hermes-import"
    "home-assistant"
    "jemalloc"
    "lang-bash"
    "lang-c"
    "lang-cpp"
    "lang-css"
    "lang-go"
    "lang-html"
    "lang-java"
    "lang-javascript"
    "lang-json"
    "lang-markdown"
    "lang-python"
    "lang-ruby"
    "lang-rust"
    "lang-toml"
    "lang-typescript"
    "langfuse"
    "llm-compaction"
    "matrix"
    "mdns"
    "metrics"
    "msteams"
    "netbird"
    "ngrok"
    "nostr"
    "openclaw-import"
    "otlp"
    "prometheus"
    "provider-github-copilot"
    "provider-kimi-code"
    "provider-openai-codex"
    "push-notifications"
    "qmd"
    "signal"
    "slack"
    "tailscale"
    "telegram"
    "telephony"
    "tls"
    "trusted-network"
    "vault"
    "vercel-sandbox"
    "voice"
    "wasm"
    "web-ui"
    "whatsapp"
  ];

  cargoBuildFlags = [
    "-p"
    "moltis"
    "--bin"
    "moltis"
  ];

  nativeBuildInputs = [
    rustPlatform.bindgenHook
    cmake
    perl
    pkg-config
    makeWrapper
  ];

  env.MOLTIS_VERSION = version;

  postPatch = ''
    sed -i '1i #![recursion_limit = "512"]' "$cargoDepsCopy"/matrix-sdk-*/src/lib.rs
  '';

  doCheck = false;

  # The binary resolves web and WASM assets from MOLTIS_SHARE_DIR. Unpack
  # share/moltis from the upstream release tarball and point the wrapper at it.
  postInstall = ''
    mkdir -p "$out/share"
    tar -xzf ${releaseArchive} -C "$out" share/moltis
    wrapProgram "$out/bin/moltis" --set-default MOLTIS_SHARE_DIR "$out/share/moltis"
  '';

  meta = {
    description = "Secure persistent personal agent server";
    homepage = "https://moltis.org";
    changelog = "https://github.com/moltis-org/moltis/releases/tag/${version}";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [
      fromSource
      binaryBytecode
    ];
    mainProgram = "moltis";
    platforms = [
      "x86_64-linux"
      "aarch64-darwin"
      "x86_64-darwin"
    ];
  };
}
