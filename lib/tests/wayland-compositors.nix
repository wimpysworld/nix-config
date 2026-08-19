let
  contract = import ../wayland-compositors.nix;
  requiredPaths = [
    [
      "launcher"
      "name"
    ]
    [
      "launcher"
      "comment"
    ]
    [
      "launcher"
      "desktopNames"
    ]
    [
      "launcher"
      "command"
    ]
    [
      "launcher"
      "prefixArgs"
    ]
    [
      "launcher"
      "logName"
    ]
    [
      "launcher"
      "nativeSessionsPath"
    ]
    [ "sessionTarget" ]
    [
      "portal"
      "backend"
    ]
    [
      "portal"
      "packageAttr"
    ]
    [
      "portal"
      "service"
    ]
    [
      "capabilities"
      "clientSideDecorations"
    ]
    [
      "capabilities"
      "picker"
    ]
    [
      "waybar"
      "workspaceModule"
    ]
    [
      "waybar"
      "workspaceSettings"
    ]
  ];
  hasAttrPath =
    path: value:
    path == [ ]
    || (
      builtins.isAttrs value
      && builtins.hasAttr (builtins.head path) value
      && hasAttrPath (builtins.tail path) value.${builtins.head path}
    );
  entriesHaveRequiredFields = builtins.all (
    entry: builtins.all (path: hasAttrPath path entry) requiredPaths
  ) (builtins.attrValues contract.compositors);
  isPureData =
    value:
    if builtins.isAttrs value then
      !(value ? type && value.type == "derivation") && builtins.all isPureData (builtins.attrValues value)
    else if builtins.isList value then
      builtins.all isPureData value
    else
      builtins.elem (builtins.typeOf value) [
        "bool"
        "float"
        "int"
        "null"
        "string"
      ];
in
assert
  builtins.attrNames contract.compositors == [
    "hyprland"
    "wayfire"
  ];
assert entriesHaveRequiredFields;
assert isPureData contract;
assert contract.default == "hyprland";
assert contract.compositors.hyprland.waybar.workspaceSettings.on-click == "activate";
assert contract.compositors.hyprland.waybar.workspaceSettings.sort-by-number;
assert !(contract.compositors.wayfire.waybar.workspaceSettings ? on-click);
assert !(contract.compositors.wayfire.waybar.workspaceSettings ? sort-by-number);
{
  compositorNames = builtins.attrNames contract.compositors;
  inherit (contract) default;
  pureData = isPureData contract;
  requiredFields = entriesHaveRequiredFields;
}
