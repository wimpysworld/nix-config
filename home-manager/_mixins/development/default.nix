{
  pkgs,
  ...
}:
{
  imports = [
    ./development.nix
    ./direnv # Modern Unix `env`
    ./claude-code
    #./dart
    ./defold
    ./gh # Terminal GitHub client`
    ./git # Terminal Git client
    ./gitkraken
    ./go
    ./jq # Terminal JSON processor
    ./just
    ./love
    ./meld
    ./nix
    ./python
    ./rust
    ./shell
    ./svelte
    ./typescript
    ./vscode
    ./yaml
    ./zed-editor
  ];
  home = {
    packages = with pkgs; [
      dconf2nix # Nix code from Dconf files
      tokei # Modern Unix `wc` for code
    ];
  };
}
