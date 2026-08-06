{
  lib,
  stdenv,
  fetchurl,
}:

stdenv.mkDerivation rec {
  pname = "wolfictl";
  version = "0.39.24";

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
        "darwin_amd64" = "da96d0235e09a9fdac150560fe80eab8c2249a2421ce2e3a07e0288bfa1fe219";
        "darwin_arm64" = "39c7fc4347e242546762942bbb032deb1f2264f4284dc2fab6f013dad8b9b64e";
        "linux_amd64" = "5b6a07073329d4354c00d51724d31b4bd3704d013ddcbd0ed39894f64e7abb97";
        "linux_arm64" = "0b9aab1592690c60deb3953673a600974613e4cd305555b3d3bff3df3f2e4ef2";
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
