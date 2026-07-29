# Chainguard publish no release binaries for yam, only Git tags, so this
# builds from source.
{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:

buildGoModule (finalAttrs: {
  pname = "yam";
  version = "0.2.65";

  src = fetchFromGitHub {
    owner = "chainguard-dev";
    repo = "yam";
    tag = "v${finalAttrs.version}";
    hash = "sha256-QqOauP/9lkaR7sf4r8yZj86spFdzy26QQATxcHVBji4=";
  };

  vendorHash = "sha256-5rf4RykeJELane+hRTiZHI6T/kczwpS51iSHVzDYNIo=";

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
