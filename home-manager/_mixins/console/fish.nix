{
  programs = {
    fish = {
      enable = true;
      interactiveShellInit = ''
      set fish_cursor_default block blink
      set fish_cursor_insert line blink
      set fish_cursor_replace_one underscore blink
      set fish_cursor_visual block
      set -U fish_color_autosuggestion brblack
      set -U fish_color_cancel -r
      set -U fish_color_command green
      set -U fish_color_comment brblack
      set -U fish_color_cwd brgreen
      set -U fish_color_cwd_root brred
      set -U fish_color_end brmagenta
      set -U fish_color_error red
      set -U fish_color_escape brcyan
      set -U fish_color_history_current --bold
      set -U fish_color_host normal
      set -U fish_color_match --background=brblue
      set -U fish_color_normal normal
      set -U fish_color_operator cyan
      set -U fish_color_param blue
      set -U fish_color_quote yellow
      set -U fish_color_redirection magenta
      set -U fish_color_search_match bryellow '--background=brblack'
      set -U fish_color_selection white --bold '--background=brblack'
      set -U fish_color_status red
      set -U fish_color_user brwhite
      set -U fish_color_valid_path --underline
      set -U fish_pager_color_completion normal
      set -U fish_pager_color_description yellow
      set -U fish_pager_color_prefix white --bold --underline
      set -U fish_pager_color_progress brwhite '--background=cyan'
      '';


      shellAbbrs = {
        mkhostid = "head -c4 /dev/urandom | od -A none -t x4";
        # https://github.com/NixOS/nixpkgs/issues/191128#issuecomment-1246030417
        nix-hash-sha256 = "nix-hash --flat --base32 --type sha256";
        nix-gc = "sudo nix-collect-garbage --delete-older-than 14d";
        rebuild-home = "home-manager switch -b backup --flake $HOME/Zero/nix-config";
        rebuild-host = "sudo nixos-rebuild switch --flake $HOME/Zero/nix-config";
        rebuild-lock = "pushd $HOME/Zero/nix-config && nix flake lock --recreate-lock-file && popd";
        rebuild-iso = "pushd $HOME/Zero/nix-config && nix build .#nixosConfigurations.iso.config.system.build.isoImage && popd";
      };
      shellAliases = {
        cat = "bat --paging=never";
        diff = "diffr";
        glow = "glow --pager";
        htop = "btm --basic --tree --hide_table_gap --dot_marker --mem_as_value";
        ip = "ip --color --brief";
        less = "bat --paging=always";
        more = "bat --paging=always";
        open = "xdg-open";
        pubip = "curl -s ifconfig.me/ip";
        #pubip = "curl -s https://api.ipify.org";
        top = "btm --basic --tree --hide_table_gap --dot_marker --mem_as_value";
        tree = "exa --tree";
        moon = "curl -s wttr.in/Moon";
        wttr = "curl -scurl -s wttr.in && curl -s v2.wttr.in";
        wttr-bas = "curl -s wttr.in/basingstoke && curl -s v2.wttr.in/basingstoke";
      };
    };
  };
}
