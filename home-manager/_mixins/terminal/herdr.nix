{
  catppuccinPalette,
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  # Herdr reads its configuration from `~/.config/herdr/config.toml`.
  tomlFormat = pkgs.formats.toml { };
  settings = {
    # Match the repository's Catppuccin Mocha theming.
    theme.name = "catppuccin";
    ui.accent = catppuccinPalette.getColor "blue";
    ui.toast.delivery = "terminal";
    # Kitty is the outer terminal, so enable kitty graphics passthrough.
    experimental.kitty_graphics = true;
    # CUA-style keybindings for tabs, workspaces, and panes.
    keys = {
      prefix = "ctrl+a";
      new_tab = "ctrl+t";
      close_tab = "ctrl+w";
      next_tab = "ctrl+tab";
      previous_tab = "ctrl+shift+tab";
      switch_tab = "ctrl+1..9";
      new_workspace = "ctrl+shift+n";
      rename_workspace = "ctrl+shift+r";
      close_workspace = "ctrl+shift+w";
      previous_workspace = "ctrl+pageup";
      next_workspace = "ctrl+pagedown";
      workspace_picker = "ctrl+shift+e";
      split_vertical = "ctrl+shift+v";
      split_horizontal = "ctrl+shift+s";
      close_pane = "ctrl+shift+x";
      focus_pane_left = "ctrl+shift+left";
      focus_pane_down = "ctrl+shift+down";
      focus_pane_up = "ctrl+shift+up";
      focus_pane_right = "ctrl+shift+right";
      zoom = "ctrl+shift+z";
      toggle_sidebar = "ctrl+shift+b";
      copy_mode = "ctrl+shift+f";
      detach = "ctrl+shift+q";
    };
  };
in
{
  config = lib.mkIf (!host.is.iso) {
    # `pkgs.herdr` comes from the `modifiedPackages` overlay, which exposes the
    # upstream flake-input build directly.
    home.packages = [
      pkgs.herdr
    ];

    xdg.configFile."herdr/config.toml".source = lib.mkDefault (
      tomlFormat.generate "herdr-config.toml" settings
    );
  };
}
