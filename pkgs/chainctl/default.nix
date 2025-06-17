{
  lib,
  stdenv,
  fetchurl,
}:

stdenv.mkDerivation rec {
  pname = "chainctl";
  version = "0.2.90";

  src = fetchurl (
    let
      # Determine system and architecture
      currentSystem = stdenv.hostPlatform.parsed.kernel.name; # "linux", "darwin"
      currentArch = stdenv.hostPlatform.parsed.cpu.name;      # "x86_64", "aarch64"
      # Map Nix architecture names to suffixes used in the URL
      archSuffix =
        if currentArch == "aarch64" then
          "arm64"
        else if currentArch == "x86_64" then
          "x86_64"
        else
          throw "chainctl: Unsupported architecture: ${currentArch}";

      # SHA256 sums derived from the Homebrew formula
      # https://github.com/chainguard-dev/homebrew-tap/blob/main/Formula/chainctl.rb
      sha256s = {
        "darwin_x86_64" = "fd78f2b32bb8157d49b3cdd16a983c560b5a313c3bd2be7f0fbea4b6b53ad8f0";
        "darwin_arm64" = "9b4c2daa06414c45ac34fd4737ec9182461e12f9432b561506a3c828e97eb7ab";
        "linux_x86_64" = "01e5f5c5d2b7310b21c0095d08dad624f12b575303eed55425c822c2931ac09b";
        "linux_arm64" = "b6d27904b5cd45bbb32d51602d159a2e1cf5873779c258e035c4833ea56636d5";
      };
      platformKey = "${currentSystem}_${archSuffix}";
    in
    {
      url = "https://dl.enforce.dev/chainctl/${version}/chainctl_${currentSystem}_${archSuffix}";
      # Look up the SHA256 sum; throw an error if not found for the current platform
      sha256 =
        sha256s.${platformKey} or (throw "chainctl: SHA256 sum not available for platform ${platformKey}");
    }
  );

  # We are fetching a single binary file
  dontUnpack = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
    install -Dm755 $src $out/bin/chainctl
    ln -s $out/bin/chainctl $out/bin/docker-credential-cgr
    runHook postInstall
  '';

  meta = with lib; {
    description = "CLI for the Chainguard Platform";
    homepage = "https://chainguard.dev";
    license = licenses.asl20;
    platforms = platforms.linux ++ platforms.darwin;
    maintainers = [ maintainers.flexiondotorg ];
  };
}
