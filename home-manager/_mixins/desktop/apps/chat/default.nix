{
  config,
  inputs,
  lib,
  pkgs,
  username,
  ...
}:
let
  installFor = [ "martin" ];
  inherit (pkgs.stdenv) isLinux;

  # Catppuccin Halloy themes from the catppuccin flake
  catppuccinHalloy = inputs.catppuccin.packages.${pkgs.system}.halloy;

  # Halloy configuration as TOML with secret placeholders
  halloyConfig = ''
    theme = "catppuccin-mocha"

    [servers.Libera-Soju]
    nickname = "Wimpy"
    alt_nicks = ["flexiondotorg", "Wimpress"]
    username = "flexiondotorg/irc.libera.chat@nixos"
    server = "irc.squidowl.org"
    port = 6697
    password = "${config.sops.placeholder.SOJU_PASSWORD}"
    use_tls = true
    on_connect = ["/msg NickServ IDENTIFY Wimpy ${config.sops.placeholder.LIBERA_PASSWORD}", "/nick Wimpy"]

    [servers.OFTC-Soju]
    nickname = "Wimpress"
    username = "flexiondotorg/irc.oftc.net@nixos"
    server = "irc.squidowl.org"
    port = 6697
    password = "${config.sops.placeholder.SOJU_PASSWORD}"
    use_tls = true
    on_connect = ["/msg NickServ IDENTIFY ${config.sops.placeholder.OFTC_PASSWORD} Wimpress"]

    [font]
    family = "FiraCode Nerd Font Mono"
    size = 18

    [buffer.text_input]
    visibility = "focused"

    [buffer.nickname]
    color = "unique"

    [buffer.nickname.brackets]
    left = ""
    right = ""

    [buffer.timestamp]
    format = "%R"

    [buffer.timestamp.brackets]
    left = "["
    right = "]"

    [buffer.server_messages.join]
    enabled = true
    smart = 3600
    username_format = "short"

    [buffer.server_messages.part]
    enabled = false
    smart = 3600
    username_format = "short"

    [buffer.server_messages.quit]
    enabled = true
    smart = 3600
    username_format = "short"

    [buffer.channel.nicklist]
    visible = true
    position = "right"
    color = "unique"

    [buffer.channel.topic]
    enabled = true

    [sidebar]
    default_action = "replace-pane"
    width = 210

    [sidebar.buttons]
    file_transfer = true
    command_bar = true

    [notifications.connected]
    enabled = false

    [notifications.highlight]
    enabled = true
  '';
in
{
  home = {
    packages =
      with pkgs;
      [
        halloy
        telegram-desktop
        zoom-us
      ]
      ++ lib.optionals (lib.elem username installFor) [
        (discord.override { withOpenASAR = true; })
      ]
      # Halloy is installed via homebrew on Darwin
      ++ lib.optionals (lib.elem username installFor && isLinux) [
        fractal
      ];
  };

  sops = lib.mkIf (lib.elem username installFor && isLinux) {
    secrets = {
      SOJU_PASSWORD.sopsFile = ../../../../../secrets/halloy.yaml;
      LIBERA_PASSWORD.sopsFile = ../../../../../secrets/halloy.yaml;
      OFTC_PASSWORD.sopsFile = ../../../../../secrets/halloy.yaml;
    };
    templates."halloy-config.toml" = {
      content = halloyConfig;
      path = "${config.xdg.configHome}/halloy/config.toml";
    };
  };

  # Install Catppuccin Mocha theme for Halloy
  xdg.configFile."halloy/themes/catppuccin-mocha.toml" =
    lib.mkIf (lib.elem username installFor && isLinux)
      {
        source = catppuccinHalloy + "/catppuccin-mocha.toml";
      };
}
