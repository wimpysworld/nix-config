{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  desktopName = if builtins.isString host.desktop then host.desktop else "";
  compositor = lib.attrByPath [
    desktopName
  ] null (import ../../../../lib/wayland-compositors.nix).compositors;
  sessionTarget = if compositor == null then "graphical-session.target" else compositor.sessionTarget;

  # Disable training, HTTP server, and alignment extras so workstations do not
  # pull PyTorch, Lightning, or Flask into the closure just for ONNX inference.
  piperTts = pkgs.piper-tts.override {
    withTrain = false;
    withHTTP = false;
    withAlignment = false;
  };

  piperSpeechd = pkgs.writeShellApplication {
    name = "piper-speechd";
    runtimeInputs = [
      piperTts
      pkgs.gawk
      pkgs.jq
      pkgs.pipewire
    ];
    text = builtins.readFile ./piper-speechd.sh;
  };
in
lib.mkIf (host.is.workstation && !host.is.iso) {
  services.speechd = {
    enable = true;
    # Configure Piper as the sole speech-dispatcher module so Brave, Chrome,
    # and Firefox expose only neural voices and never fall back to eSpeak.
    config = ''
      LogLevel 3
      LogDir "default"
      DefaultVolume 100
      DefaultLanguage "en-gb"
      SymbolsPreproc "char"
      SymbolsPreprocFile "gender-neutral.dic"
      SymbolsPreprocFile "font-variants.dic"
      SymbolsPreprocFile "symbols.dic"
      SymbolsPreprocFile "emojis.dic"
      SymbolsPreprocFile "orca.dic"
      SymbolsPreprocFile "orca-chars.dic"
      AddModule "piper-generic" "sd_generic" "piper-generic.conf"
      DefaultModule piper-generic
      LanguageDefaultModule "en" "piper-generic"
      LanguageDefaultModule "en-gb" "piper-generic"
      LanguageDefaultModule "en-us" "piper-generic"
      Include "clients/*.conf"
    '';
    modules.piper-generic = ''
      Debug 0
      GenericExecuteSynth "printf %s '$DATA' | ${lib.getExe piperSpeechd} '${pkgs.piper-voices}/share/piper-voices' '$VOICE' '$RATE' '$VOLUME'"
      GenericDefaultCharset "utf-8"
      GenericRateAdd 0
      GenericRateMultiply 100
      GenericRateForceInteger 1
      GenericVolumeAdd 50
      GenericVolumeMultiply 50
      GenericVolumeForceInteger 1
      AddVoice "en-gb" "FEMALE1" "en_GB-cori-medium"
      AddVoice "en-gb" "MALE1" "en_GB-alan-medium"
      DefaultVoice "en_GB-cori-medium"
    '';
  };

  # Start speech-dispatcher eagerly with the graphical session so browsers see
  # voices immediately without hitting NixOS socket-activation detection bugs.
  systemd.user.services.speech-dispatcher = {
    overrideStrategy = "asDropin";
    after = [
      "pipewire.service"
      "wireplumber.service"
      sessionTarget
    ];
    partOf = [ sessionTarget ];
    wantedBy = [ sessionTarget ];
  };
}
