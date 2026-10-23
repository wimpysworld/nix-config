{ config, lib, ... }:
let
  inherit (config.noughty) host;
  # A comma inside a pattern would split the rule, so no pattern uses one.
  floatBy = field: pattern: "is_floating:1,${field}:${pattern}";
  floatSized =
    field: pattern: width: height:
    "is_floating:1,width:${toString width},height:${toString height},${field}:${pattern}";
  opaqueBy = field: pattern: "focused_opacity:1.0,unfocused_opacity:1.0,${field}:${pattern}";
  layerAnimations =
    name: open: close:
    "layer_name:^${name}$,animation_type_open:${open},animation_type_close:${close}";
in
{
  config = lib.mkIf (host.desktop == "mango") {
    wayland.windowManager.mango.settings = {
      window_rule = [
        # Pop-up file dialogs
        (floatBy "title" "(Open|Progress|Save File)")
        (floatBy "app_id" "(xdg-desktop-portal-gtk)")
        # VS Code child windows, but not the main editor window
        "is_floating:1,app_id:^code$,title:^(?!.*Visual Studio Code)"

        # Floating utilities
        (floatSized "title" "Maestral Settings" 600 402)
        (floatSized "title" "MainPicker" 512 290)
        (floatSized "title" "overskride" 880 1010)
        (floatSized "title" "Pipewire Volume Control" 1134 880)
        (floatSized "title" "Trayscale" 886 960)
        (floatSized "title" "Polychromatic" 960 640)
        (floatBy "title" "Syncthing Tray")
        (floatSized "app_id" "^\\.blueman-manager-wrapped$" 700 580)
        (floatSized "app_id" "^blueberry\\.py$" 580 640)
        (floatSized "app_id" "^nm-connection-editor$" 700 500)
        (floatSized "app_id" "^org\\.gnome\\.Calculator$" 395 496)
        (floatBy "app_id" "^polkit-gnome-authentication-agent-1$")

        # Windows that should never be translucent
        (opaqueBy "app_id" "com.obsproject.Studio")
        (opaqueBy "app_id" "resolve")
        (opaqueBy "app_id" "com.defold.editor.Start")
        (opaqueBy "app_id" "dmengine")
        (opaqueBy "app_id" "Gimp")
        (opaqueBy "app_id" "love")
        (opaqueBy "title" "UNIGINE Engine")
        (opaqueBy "title" "Steam Big Picture Mode")
        (opaqueBy "title" "^QEMU")
      ];
      layer_rule = [
        (layerAnimations "launcher" "zoom" "fade")
        (layerAnimations "rofi" "zoom" "fade")
        (layerAnimations "wleave" "fade" "fade")
        # SwayNC draws its shadow in a transparent margin. Mango has no
        # alpha threshold for blur, so blur would fill that margin. A compositor shadow would
        # also sit outside the margin. Both fields stay in the same rule,
        # because a later matching rule resets no_blur.
        "${layerAnimations "swaync-notification-window" "slide" "fade"},no_blur:1,no_shadow:1"
        "${layerAnimations "swaync-control-center" "slide" "fade"},no_blur:1,no_shadow:1"
        "layer_name:^selection$,no_animation:1,no_blur:1,no_shadow:1"
        "layer_name:^avizo$,no_animation:1,no_shadow:1"
        "layer_name:^wpaperd$,no_animation:1,no_blur:1,no_shadow:1"
        # The Waybar pills are small and already 85 per cent opaque, so blur
        # behind them is hard to see and not worth the work.
        "layer_name:^waybar$,no_blur:1"
      ];
    };
  };
}
