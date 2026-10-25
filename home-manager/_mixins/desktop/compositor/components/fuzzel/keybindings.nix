{
  pkgs,
  fuzzel,
  configFile,
  entries,
}:
assert pkgs.lib.assertMsg (pkgs.lib.versionAtLeast fuzzel.version "1.14")
  "fuzzel-keybindings requires Fuzzel >= 1.14 for hidden search fields";
let
  pickerConfig = pkgs.writeText "fuzzel-keybindings.ini" ''
    [main]
    include=${configFile}

    [key-bindings]
    execute-input=none
  '';
  catalogue = pkgs.writeText "fuzzel-keybindings.json" (builtins.toJSON entries);
in
pkgs.writeShellApplication {
  name = "fuzzel-keybindings";
  runtimeInputs = [
    fuzzel
    pkgs.python3
  ];
  text = ''
    exec python3 ${./fuzzel-keybindings.py} ${catalogue} ${pickerConfig}
  '';
  derivationArgs.postCheck = ''
    ${pkgs.python3}/bin/python3 ${./test-keybindings.py} \
      ${./fuzzel-keybindings.py} ${pickerConfig}
  '';
}
