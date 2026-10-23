{ catppuccinPalette, lib }:
let
  # Mango silently truncates a value longer than 255 bytes, so `mango -p`
  # cannot catch an overlong binding or rule.
  maxValueLength = 255;

  # builtins.toString renders 1.0 as "1.000000"; toJSON gives "1.0", and the
  # trailing ".0" is trimmed.
  floatStr =
    f:
    let
      s = builtins.toJSON f;
      len = builtins.stringLength s;
    in
    if len >= 2 && builtins.substring (len - 2) 2 s == ".0" then
      builtins.substring 0 (len - 2) s
    else
      s;

  renderValue =
    value:
    if builtins.isBool value then
      (if value then "1" else "0")
    else if builtins.isInt value then
      toString value
    else if builtins.isFloat value then
      floatStr value
    else
      value;

  checkedLine =
    key: value:
    assert lib.assertMsg (
      builtins.stringLength value <= maxValueLength
    ) "Mango ${key} value is longer than ${toString maxValueLength} bytes: ${value}";
    "${key}=${value}";

  # An empty value is a parse error in Mango, so keys and list elements that
  # render to the empty string are dropped.
  renderKey =
    key: value:
    let
      values = map renderValue (lib.toList value);
    in
    map (checkedLine key) (builtins.filter (v: v != "") values);

  # Key mode lines are complete `key=value` lines; split them to check the value.
  renderModeLine =
    line:
    let
      parts = builtins.match "([^=]+)=(.*)" line;
    in
    assert lib.assertMsg (parts != null) "Mango key mode line has no '=': ${line}";
    checkedLine (builtins.elemAt parts 0) (builtins.elemAt parts 1);
in
{
  inherit floatStr;

  # Render settings as Mango `key=value` lines. Scalar keys come first, then
  # repeated keys with one line per list element in list order, then
  # `exec_once`. Each key mode follows as a `key_mode` block, because a binding
  # belongs to the mode that is current when Mango parses it.
  toMangoConf =
    settings: keymodes: extraConfig:
    let
      names = builtins.attrNames settings;
      scalarNames = builtins.filter (name: !builtins.isList settings.${name}) names;
      listNames = builtins.filter (name: builtins.isList settings.${name} && name != "exec_once") names;
      lines =
        lib.concatMap (name: renderKey name settings.${name}) scalarNames
        ++ lib.concatMap (name: renderKey name settings.${name}) listNames
        ++ renderKey "exec_once" (settings.exec_once or [ ])
        ++ lib.concatLists (
          lib.mapAttrsToList (
            name: modeLines: [ "key_mode=${name}" ] ++ map renderModeLine modeLines ++ [ "key_mode=default" ]
          ) keymodes
        );
    in
    lib.concatStringsSep "\n" lines + "\n" + extraConfig;

  # Convert a Catppuccin colour name and an alpha between 0 and 1 to 0xRRGGBBAA.
  toMangoColor =
    name: alpha:
    let
      alphaHex = lib.toLower (lib.toHexString (builtins.floor (alpha * 255 + 0.5)));
    in
    "0x${builtins.substring 1 (-1) (catppuccinPalette.getColor name)}${
      lib.fixedWidthString 2 "0" alphaHex
    }";

  # Mix two Catppuccin colours into one opaque-looking 0xRRGGBBAA value.
  # The weight is the share of the first colour, between 0 and 1. A solid
  # mix avoids the muddy result of a translucent accent over the windows.
  mixMangoColor =
    first: second: weight: alpha:
    let
      channel =
        name: offset: lib.fromHexString (builtins.substring offset 2 (catppuccinPalette.getColor name));
      hex2 = n: lib.fixedWidthString 2 "0" (lib.toLower (lib.toHexString n));
      mixChannel =
        offset:
        hex2 (builtins.floor (weight * channel first offset + (1 - weight) * channel second offset + 0.5));
    in
    "0x${mixChannel 1}${mixChannel 3}${mixChannel 5}${hex2 (builtins.floor (alpha * 255 + 0.5))}";
}
