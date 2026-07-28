{ pkgs }:

{
  setupShell = ''
    setup_fence_git() {
      local git_config_index
      local git_common_dir
      local home_dir

      git_config_index="''${GIT_CONFIG_COUNT:-0}"
      case "$git_config_index" in
        *[!0-9]*)
          printf 'fence: GIT_CONFIG_COUNT must be a decimal integer from 0 to 1024.\n' >&2
          return 1
          ;;
      esac

      if (( ''${#git_config_index} > 4 )); then
        printf 'fence: GIT_CONFIG_COUNT must be a decimal integer from 0 to 1024.\n' >&2
        return 1
      fi

      git_config_index=$((10#$git_config_index))
      if (( git_config_index > 1024 )); then
        printf 'fence: GIT_CONFIG_COUNT must be a decimal integer from 0 to 1024.\n' >&2
        return 1
      fi

      # Signing follows the repository, not the directory. Ask Git for the
      # common directory of the repository that owns the launch directory. For
      # a linked worktree that is the main repository rather than the worktree
      # checkout, so a work worktree placed anywhere still counts as work.
      #
      # Work clones live under ~/Chainguard and sign with gitsign, which needs
      # no key inside the sandbox. Inject nothing there so the `gitdir:`
      # include in the Git configuration governs signing. Everywhere else the
      # base configuration signs with an SSH key that Fence read-denies, so
      # turn signing off or the commit fails.
      #
      # The pattern requires a component between Chainguard and the Git
      # directory, so ~/Chainguard/<repo>/.git matches. ~/Chainguard itself is
      # a personal repository whose common directory is ~/Chainguard/.git.
      # That has no such component, so it takes the unsigned path.
      #
      # The decision is still made once, at launch, because `GIT_CONFIG_*` is
      # process environment. A repository that cannot be resolved, including a
      # launch directory outside any repository, falls through to unsigned.
      # Failing closed that way is safe: the opposite error would sign a work
      # commit with a personal identity.
      if ! git_common_dir="$(${pkgs.lib.getExe pkgs.git} rev-parse --path-format=absolute --git-common-dir 2>/dev/null)"; then
        git_common_dir=""
      fi

      if ! home_dir="$(${pkgs.lib.getExe' pkgs.coreutils "realpath"} -- "$HOME" 2>/dev/null)"; then
        home_dir=""
      fi

      if [[ -n "$git_common_dir" && -n "$home_dir" ]]; then
        case "$git_common_dir" in
          "$home_dir"/Chainguard/*/*)
            return 0
            ;;
        esac
      fi

      fence_env+=(
        "GIT_CONFIG_COUNT=$((git_config_index + 2))"
        "GIT_CONFIG_KEY_$git_config_index=commit.gpgSign"
        "GIT_CONFIG_VALUE_$git_config_index=false"
        "GIT_CONFIG_KEY_$((git_config_index + 1))=tag.gpgSign"
        "GIT_CONFIG_VALUE_$((git_config_index + 1))=false"
      )
    }

    setup_fence_git
  '';
}
