{
  lib,
  stdenv,
  fetchurl,
}:

stdenv.mkDerivation rec {
  pname = "wolfictl";
  version = "0.39.32";

  src = fetchurl (
    let
      # Determine system and architecture
      currentSystem = stdenv.hostPlatform.parsed.kernel.name; # "linux", "darwin"
      currentArch = stdenv.hostPlatform.parsed.cpu.name; # "x86_64", "aarch64"
      # Map Nix architecture names to suffixes used in the URL
      archSuffix =
        if currentArch == "aarch64" then
          "arm64"
        else if currentArch == "x86_64" then
          "amd64"
        else
          throw "wolfictl: Unsupported architecture: ${currentArch}";

      # SHA256 sums from the release checksums.txt
      # https://github.com/wolfi-dev/wolfictl/releases/download/v${version}/wolfictl_checksums.txt
      sha256s = {
        "darwin_amd64" = "2f7b41ff1c986bd46d5277dbcb65a5fde308e8212cbfe4e7f62563d32e4f779e";
        "darwin_arm64" = "2958dc572ea23eb624c529db125d4a243b504476c2416de0f4d1c4887f616d36";
        "linux_amd64" = "c00df5b291993feb22c56525b42e5ac13a7f7255ca4ee68527ca1d2c0ebe1ce6";
        "linux_arm64" = "cc75bcf98cfb057079058edc9de8abeba2b513e63bbfdfb7708510a31f063839";
      };
      platformKey = "${currentSystem}_${archSuffix}";
    in
    {
      url = "https://github.com/wolfi-dev/wolfictl/releases/download/v${version}/wolfictl_${currentSystem}_${archSuffix}_${version}_${currentSystem}_${archSuffix}";
      # Look up the SHA256 sum; throw an error if not found for the current platform
      sha256 =
        sha256s.${platformKey} or (throw "wolfictl: SHA256 sum not available for platform ${platformKey}");
    }
  );

  # We are fetching a single binary file
  dontUnpack = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
    install -Dm755 $src $out/bin/wolfictl
    runHook postInstall
  '';

  meta = with lib; {
    description = "A CLI used to work with the Wolfi OSS project";
    homepage = "https://github.com/wolfi-dev/wolfictl";
    license = licenses.asl20;
    platforms = platforms.linux ++ platforms.darwin;
    maintainers = [ maintainers.flexiondotorg ];
  };
}
