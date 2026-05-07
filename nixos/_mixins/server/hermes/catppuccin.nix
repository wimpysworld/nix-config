{
  config,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  hermesHome = "${config.services.hermes-agent.stateDir}/.hermes";
  hermesUser = config.services.hermes-agent.user;
  hermesGroup = config.services.hermes-agent.group;

  skinFormat = pkgs.formats.yaml { };

  palettes = {
    latte = {
      description = "Catppuccin Latte — bright light theme with soft readable accents";
      colours = {
        rosewater = "#dc8a78";
        flamingo = "#dd7878";
        pink = "#ea76cb";
        mauve = "#8839ef";
        red = "#d20f39";
        maroon = "#e64553";
        peach = "#fe640b";
        yellow = "#df8e1d";
        green = "#40a02b";
        teal = "#179299";
        sky = "#04a5e5";
        sapphire = "#209fb5";
        blue = "#1e66f5";
        lavender = "#7287fd";
        text = "#4c4f69";
        subtext1 = "#5c5f77";
        subtext0 = "#6c6f85";
        overlay2 = "#7c7f93";
        overlay1 = "#8c8fa1";
        overlay0 = "#9ca0b0";
        surface2 = "#acb0be";
        surface1 = "#bcc0cc";
        surface0 = "#ccd0da";
        base = "#eff1f5";
        mantle = "#e6e9ef";
        crust = "#dce0e8";
      };
    };

    frappe = {
      description = "Catppuccin Frappé — balanced medium-contrast dark theme";
      colours = {
        rosewater = "#f2d5cf";
        flamingo = "#eebebe";
        pink = "#f4b8e4";
        mauve = "#ca9ee6";
        red = "#e78284";
        maroon = "#ea999c";
        peach = "#ef9f76";
        yellow = "#e5c890";
        green = "#a6d189";
        teal = "#81c8be";
        sky = "#99d1db";
        sapphire = "#85c1dc";
        blue = "#8caaee";
        lavender = "#babbf1";
        text = "#c6d0f5";
        subtext1 = "#b5bfe2";
        subtext0 = "#a5adce";
        overlay2 = "#949cbb";
        overlay1 = "#838ba7";
        overlay0 = "#737994";
        surface2 = "#626880";
        surface1 = "#51576d";
        surface0 = "#414559";
        base = "#303446";
        mantle = "#292c3c";
        crust = "#232634";
      };
    };

    macchiato = {
      description = "Catppuccin Macchiato — deep midnight dark theme";
      colours = {
        rosewater = "#f4dbd6";
        flamingo = "#f0c6c6";
        pink = "#f5bde6";
        mauve = "#c6a0f6";
        red = "#ed8796";
        maroon = "#ee99a0";
        peach = "#f5a97f";
        yellow = "#eed49f";
        green = "#a6da95";
        teal = "#8bd5ca";
        sky = "#91d7e3";
        sapphire = "#7dc4e4";
        blue = "#8aadf4";
        lavender = "#b7bdf8";
        text = "#cad3f5";
        subtext1 = "#b8c0e0";
        subtext0 = "#a5adcb";
        overlay2 = "#939ab7";
        overlay1 = "#8087a2";
        overlay0 = "#6e738d";
        surface2 = "#5b6078";
        surface1 = "#494d64";
        surface0 = "#363a4f";
        base = "#24273a";
        mantle = "#1e2030";
        crust = "#181926";
      };
    };

    mocha = {
      description = "Catppuccin Mocha — warm dark theme with soft pastels";
      colours = {
        rosewater = "#f5e0dc";
        flamingo = "#f2cdcd";
        pink = "#f5c2e7";
        mauve = "#cba6f7";
        red = "#f38ba8";
        maroon = "#eba0ac";
        peach = "#fab387";
        yellow = "#f9e2af";
        green = "#a6e3a1";
        teal = "#94e2d5";
        sky = "#89dceb";
        sapphire = "#74c7ec";
        blue = "#89b4fa";
        lavender = "#b4befe";
        text = "#cdd6f4";
        subtext1 = "#bac2de";
        subtext0 = "#a6adc8";
        overlay2 = "#9399b2";
        overlay1 = "#7f849c";
        overlay0 = "#6c7086";
        surface2 = "#585b70";
        surface1 = "#45475a";
        surface0 = "#313244";
        base = "#1e1e2e";
        mantle = "#181825";
        crust = "#11111b";
      };
    };
  };

  mkSkin =
    flavour: palette:
    let
      c = palette.colours;
    in
    skinFormat.generate "catppuccin-${flavour}.yaml" {
      name = "catppuccin-${flavour}";
      inherit (palette) description;
      colors = {
        banner_border = c.surface0;
        banner_title = c.text;
        banner_accent = c.lavender;
        banner_dim = c.overlay0;
        banner_text = c.subtext1;
        ui_accent = c.blue;
        ui_label = c.teal;
        ui_ok = c.green;
        ui_error = c.red;
        ui_warn = c.yellow;
        prompt = c.text;
        input_rule = c.surface1;
        response_border = c.mauve;
        status_bar_bg = c.mantle;
        status_bar_text = c.subtext1;
        status_bar_strong = c.lavender;
        status_bar_dim = c.overlay0;
        status_bar_good = c.green;
        status_bar_warn = c.yellow;
        status_bar_bad = c.peach;
        status_bar_critical = c.red;
        session_label = c.sapphire;
        session_border = c.surface2;
        voice_status_bg = c.mantle;
        completion_menu_bg = c.mantle;
        completion_menu_current_bg = c.surface0;
        completion_menu_meta_bg = c.mantle;
        completion_menu_meta_current_bg = c.surface0;
      };
      spinner = {
        waiting_faces = [
          "𓃭"
          "◆"
          "◉"
        ];
        thinking_faces = [
          "◌"
          "◎"
          "◈"
        ];
        thinking_verbs = [
          "brewing"
          "steeping"
          "fermenting thoughts"
          "distilling"
        ];
        wings = [
          [
            "╰◆ "
            " ◆╯"
          ]
          [
            "╰◈ "
            " ◈╯"
          ]
        ];
      };
      branding = {
        agent_name = "Hermes Agent";
        response_label = " ⚕ Hermes ";
        prompt_symbol = "❯";
        help_header = "(?) Available Commands";
      };
      tool_prefix = "│";
    };

  catppuccinSkins = lib.mapAttrs mkSkin palettes;

  catppuccinSkinPackage = pkgs.runCommand "hermes-catppuccin-skins" { } ''
    mkdir -p "$out/share/hermes/skins"
    ${lib.concatStringsSep "\n" (
      lib.mapAttrsToList (flavour: skin: ''
        cp ${skin} "$out/share/hermes/skins/catppuccin-${flavour}.yaml"
      '') catppuccinSkins
    )}
  '';
in
{
  config = lib.mkIf (noughtyLib.hostHasTag "hermes") {
    services.hermes-agent.settings.display.skin = "catppuccin-mocha";

    system.activationScripts.hermes-catppuccin-skins =
      lib.stringAfter
        [
          "users"
          "groups"
          "hermes-agent-setup"
        ]
        ''
          install -d -m 2770 -o ${hermesUser} -g ${hermesGroup} ${hermesHome}/skins
          for skin in ${catppuccinSkinPackage}/share/hermes/skins/*.yaml; do
            install -m 0640 -o ${hermesUser} -g ${hermesGroup} "$skin" ${hermesHome}/skins/"$(basename "$skin")"
          done
        '';
  };
}
