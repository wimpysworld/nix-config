# OpenChamber Web - browser-based GUI for the OpenCode AI coding agent.
# The npm tarball ships pre-built dist/ and server/ assets; only node-pty
# requires native compilation at install time.
{
  lib,
  buildNpmPackage,
  fetchurl,
  python3,
  pkg-config,
  nodePackages,
}:
let
  version = "1.8.2";
in
buildNpmPackage {
  pname = "openchamber-web";
  inherit version;

  # Use the pre-built tarball from GitHub releases rather than the npm registry.
  # The GitHub release tarball matches the npm publish exactly and is easier to
  # pin for the freshener workflow.
  src = fetchurl {
    url = "https://github.com/btriapitsyn/openchamber/releases/download/v${version}/openchamber-web-${version}.tgz";
    hash = "sha256-+bVPXBoBjBOUW5I2FRS1a6WSvFrhJswdK+hRKTABFxg=";
  };

  # The tarball extracts to a "package/" directory.
  sourceRoot = "package";

  # The upstream project uses bun.lock; the npm tarball has no package-lock.json.
  # Supply a generated lockfile so buildNpmPackage can compute the dependency hash.
  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

  # node-pty requires python3, node-gyp, and a C++ toolchain at build time.
  nativeBuildInputs = [
    python3
    pkg-config
    nodePackages.node-gyp
  ];

  npmDepsHash = "sha256-/yjs9wGPpFsTAYiwPN6Y0TFdxCKzz+m6PScRSgE8mIQ=";

  # The package ships pre-built dist/ and server/ - no build step needed.
  dontNpmBuild = true;

  # Keep install scripts disabled (the default) to avoid broken postinstall
  # hooks from packages like @ibm/plex. Compile node-pty natively afterwards.
  postInstall = ''
    cd "$out/lib/node_modules/@openchamber/web"
    npm rebuild node-pty
  '';

  meta = {
    changelog = "https://github.com/btriapitsyn/openchamber/releases/tag/v${version}";
    description = "Web interface for the OpenCode AI coding agent";
    homepage = "https://github.com/btriapitsyn/openchamber";
    license = lib.licenses.mit;
    mainProgram = "openchamber";
    maintainers = with lib.maintainers; [ flexiondotorg ];
    platforms = lib.platforms.linux;
  };
}
