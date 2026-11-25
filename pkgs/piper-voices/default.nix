{
  lib,
  fetchurl,
  runCommand,
}:
let
  version = "1.0.0";
  baseUrl = "https://huggingface.co/rhasspy/piper-voices/resolve/v${version}";

  voices = [
    {
      name = "en_GB-cori-medium";
      path = "en/en_GB/cori/medium/en_GB-cori-medium";
      onnxHash = "sha256-GJn5jl+4MQFU88KXP0uKkpunJF5yKz06hWgLgz2V8Q0=";
      jsonHash = "sha256-4mLBbX8ZL2nU7da074pZFTeeZ0lfzEAvGrFe6zPaPTY=";
    }
    {
      name = "en_GB-alan-medium";
      path = "en/en_GB/alan/medium/en_GB-alan-medium";
      onnxHash = "sha256-CjCWaJMiBedigB8e/Cc2zUsBIDKWIq32K+CeVjOdMzA=";
      jsonHash = "sha256-wPDRJOWJXADnwDs13MgofzGaaZijZbGC3rXI51LujB4=";
    }
  ];

  installVoice =
    voice:
    let
      onnx = fetchurl {
        url = "${baseUrl}/${voice.path}.onnx";
        hash = voice.onnxHash;
      };
      json = fetchurl {
        url = "${baseUrl}/${voice.path}.onnx.json";
        hash = voice.jsonHash;
      };
    in
    ''
      ln -s ${onnx} "$out/share/piper-voices/${voice.name}.onnx"
      ln -s ${json} "$out/share/piper-voices/${voice.name}.onnx.json"
    '';
in
runCommand "piper-voices-${version}"
  {
    meta = {
      description = "Curated British English neural voice models for Piper TTS";
      homepage = "https://huggingface.co/rhasspy/piper-voices";
      license = lib.licenses.mit;
      platforms = lib.platforms.all;
    };
  }
  ''
    mkdir -p "$out/share/piper-voices"
    ${lib.concatMapStrings installVoice voices}
  ''
