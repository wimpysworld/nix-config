{
  config,
  lib,
  pkgs,
  ...
}:
let
  # Offer to rebuild a stale nix-direnv cache from the shell prompt.
  #
  # A repository opts in with `nix_direnv_manual_reload` in its `.envrc`. With
  # that setting nix-direnv only logs "cache is out of date" and keeps the old
  # environment. The check below runs in the interactive shell on every prompt
  # and mirrors nix-direnv: the cache is stale when `.envrc`, `flake.nix`, or
  # `flake.lock` is newer than `.direnv/flake-profile-*.rc`. The shell then asks
  # once, with its own `read` builtin, and runs the `nix-direnv-reload` helper
  # that nix-direnv writes to `.direnv/bin`.
  #
  # The check reads files directly rather than a variable exported by `.envrc`
  # because direnv-instant applies the direnv environment asynchronously through
  # a signal trap, which the shell services one prompt late. A "no" answer is
  # remembered against the repository until the cache is current again.
  staleFiles = [
    ".envrc"
    "flake.nix"
    "flake.lock"
  ];
  promptText = "nix-direnv: cache is stale. Reload now? [y/N] ";
  bashLike = readBuiltin: ''
    __nix_direnv_stale_prompt() {
      local dir="$PWD" file rc="" stale=0 answer=""
      while [[ -n "$dir" && ! -f "$dir/.envrc" ]]; do
        dir="''${dir%/*}"
      done
      if [[ -z "$dir" ]] || ! ${lib.getExe pkgs.gnugrep} -qs '^nix_direnv_manual_reload' "$dir/.envrc"; then
        __nix_direnv_stale_asked=""
        return 0
      fi
      [[ -x "$dir/.direnv/bin/nix-direnv-reload" ]] || return 0
      for file in "$dir"/.direnv/flake-profile-*.rc; do
        [[ -e "$file" ]] && rc="$file" && break
      done
      if [[ -z "$rc" ]]; then
        stale=1
      else
        for file in ${lib.escapeShellArgs staleFiles}; do
          [[ -e "$dir/$file" && "$dir/$file" -nt "$rc" ]] && stale=1
        done
      fi
      if [[ "$stale" -eq 0 ]]; then
        __nix_direnv_stale_asked=""
        return 0
      fi
      [[ "''${__nix_direnv_stale_asked:-}" == "$dir" ]] && return 0
      __nix_direnv_stale_asked="$dir"
      ${readBuiltin}
      case "$answer" in
        y | Y | yes | YES | Yes)
          "$dir/.direnv/bin/nix-direnv-reload"
          ;;
        *)
          echo "nix-direnv: run nix-direnv-reload when ready." >&2
          ;;
      esac
      return 0
    }
  '';
in
{
  home = {
    # https://github.com/direnv/direnv/issues/1084
    sessionVariables = {
      DIRENV_WARN_TIMEOUT = "120s";
    };
  };
  programs = {
    direnv = {
      enable = true;
      enableBashIntegration = config.programs.bash.enable;
      enableZshIntegration = config.programs.zsh.enable;
      nix-direnv = {
        enable = true;
      };
    };
    # Non-blocking direnv shell integration; runs evaluation asynchronously
    # in the background and spawns a multiplexer pane after a delay.
    # https://github.com/Mic92/direnv-instant
    direnv-instant = {
      enable = true;
      enableBashIntegration = config.programs.bash.enable;
      enableFishIntegration = false; # HM stable 25.11 makes enableFishIntegration read-only; erased in fish init below
      enableZshIntegration = config.programs.zsh.enable;
    };
    bash.initExtra = lib.mkAfter (
      bashLike ''read -r -p ${lib.escapeShellArg promptText} answer < /dev/tty || answer=""''
      + ''
        PROMPT_COMMAND="''${PROMPT_COMMAND:+$PROMPT_COMMAND;}__nix_direnv_stale_prompt"
      ''
    );
    zsh.initContent = lib.mkAfter (
      bashLike ''read -r "answer?${promptText}" < /dev/tty || answer=""''
      + ''
        precmd_functions+=(__nix_direnv_stale_prompt)
      ''
    );
    fish = lib.mkIf config.programs.fish.enable {
      interactiveShellInit = lib.mkMerge [
        (lib.mkBefore ''
          # Prevent standard direnv hook from firing; direnv-instant handles this
          functions --erase __direnv_export_eval 2>/dev/null
          functions --erase __direnv_cd_hook 2>/dev/null
        '')
        ''
          function __nix_direnv_stale_prompt --on-event fish_prompt
            set -l dir $PWD
            while test -n "$dir"; and not test -f "$dir/.envrc"
              set dir (string replace -r '/[^/]*$' "" -- $dir)
            end
            if test -z "$dir"; or not ${lib.getExe pkgs.gnugrep} -qs '^nix_direnv_manual_reload' "$dir/.envrc"
              set -g __nix_direnv_stale_asked ""
              return 0
            end
            test -x "$dir/.direnv/bin/nix-direnv-reload"; or return 0
            set -l rc $dir/.direnv/flake-profile-*.rc
            set -l stale 0
            if test (count $rc) -eq 0
              set stale 1
            else
              for file in ${lib.concatStringsSep " " staleFiles}
                if test -e "$dir/$file"; and test "$dir/$file" -nt "$rc[1]"
                  set stale 1
                end
              end
            end
            if test $stale -eq 0
              set -g __nix_direnv_stale_asked ""
              return 0
            end
            if test "$__nix_direnv_stale_asked" = "$dir"
              return 0
            end
            set -g __nix_direnv_stale_asked "$dir"
            read -l -P ${lib.escapeShellArg promptText} answer
            switch "$answer"
              case y Y yes YES Yes
                "$dir/.direnv/bin/nix-direnv-reload"
              case '*'
                echo "nix-direnv: run nix-direnv-reload when ready." >&2
            end
            return 0
          end
        ''
      ];
    };
    zed-editor = lib.mkIf config.programs.zed-editor.enable {
      userSettings = {
        load_direnv = "shell_hook";
      };
    };
  };
}
