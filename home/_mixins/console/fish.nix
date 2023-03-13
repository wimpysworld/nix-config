{
  programs = {
    fish = {
      enable = true;
      shellAliases = {
        cat = "bat";
        diff = "diffr";
        ip = "ip --color";
        ipb = "ip --color --brief";
        less = "bat";
        man = "env PAGER=most man";
        open = "xdg-open";
        top = "btm --basic --tree";
        tree = "exa --tree";
        speedtest = "speedtest-rs";

        nix-gc = "sudo nix-collect-garbage --delete-older-than 14d";
        rebuild-home = "home-manager switch -b backup --flake $HOME/Zero/nix-config";
        rebuild-host = "sudo nixos-rebuild switch --flake $HOME/Zero/nix-config";
      };
    };
  };
}
