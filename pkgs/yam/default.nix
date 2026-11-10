# Chainguard publish no release binaries for yam, only Git tags, so this
# builds from source.
{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:

buildGoModule (finalAttrs: {
  pname = "yam";
  version = "0.2.70";

  src = fetchFromGitHub {
    owner = "chainguard-dev";
    repo = "yam";
    tag = "v${finalAttrs.version}";
    hash = "sha256-PLHg3RA1b13D7JCqbPx2tH/fcb9yqOMx/LR+Qk2MDQY=";
  };

  vendorHash = "sha256-hh6vsOjIo4Ph6awTMUlBdDlv5e8kAPRL3Eyb6U9Agl0=";

  meta = {
    description = "Sweet little formatter for YAML";
    homepage = "https://github.com/chainguard-dev/yam";
    changelog = "https://github.com/chainguard-dev/yam/commits/v${finalAttrs.version}";
    license = lib.licenses.asl20;
    maintainers = with lib.maintainers; [ flexiondotorg ];
    mainProgram = "yam";
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
})
