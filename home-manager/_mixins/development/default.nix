{
  pkgs,
  ...
}:
{
  imports = [
    ./development.nix
    ./direnv # Modern Unix `env`
    ./claude-code
    ./defold
    ./gh # Terminal GitHub client`
    ./git # Terminal Git client
    ./gitkraken
    ./go
    ./jq # Terminal JSON processor
    ./love
    ./meld
    ./nix
    ./svelte
    ./typescript
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
