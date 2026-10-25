{
  pkgs,
  fuzzel,
  configFile,
}:
assert pkgs.lib.assertMsg (pkgs.lib.versionAtLeast fuzzel.version "1.14")
  "fuzzel-emoji requires Fuzzel >= 1.14 for hidden search fields";
let
  pickerConfig = pkgs.writeText "fuzzel-emoji.ini" ''
    [main]
    include=${configFile}

    [key-bindings]
    execute-input=none
  '';
in
pkgs.writeShellApplication {
  name = "fuzzel-emoji";
  runtimeInputs = [
    fuzzel
    pkgs.python3
    pkgs.wtype
    pkgs.wl-clipboard
  ];
  runtimeEnv = {
    FUZZEL_EMOJI_HELPER = "${./fuzzel-emoji.py}";
    FUZZEL_EMOJI_MASTER = "${pkgs.fuzzel-emoji-data}/share/fuzzel-emoji/master.json";
    FUZZEL_EMOJI_CONFIG = "${pickerConfig}";
  };
  text = builtins.readFile ./fuzzel-emoji.sh;
  derivationArgs.postCheck = ''
    ${pkgs.python3}/bin/python3 ${./test-emoji.py} \
      ${./fuzzel-emoji.py} ${./fuzzel-emoji.sh} ${pickerConfig} \
      ${pkgs.fuzzel-emoji-data}/share/fuzzel-emoji/master.json
  '';
}
