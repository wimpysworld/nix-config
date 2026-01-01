{
  pkgs,
  ...
}:
{
  imports = [
    ./development.nix
    ./claude-code
    ./defold
    ./gitkraken
    ./love
    ./meld
    ./vscode
    ./zed-editor
  ];
  home = {
    packages = with pkgs; [
      dconf2nix # Nix code from Dconf files
      tokei # Modern Unix `wc` for code
      yq-go # Terminal `jq` for YAML
    ];
  };
}
