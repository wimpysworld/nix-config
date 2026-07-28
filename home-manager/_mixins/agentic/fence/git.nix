{
  setupShell = ''
    setup_fence_git() {
      local git_config_index

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

      # Work clones live under ~/Chainguard and sign with gitsign, which needs
      # no key inside the sandbox. Inject nothing there so the `gitdir:` include
      # in the Git configuration governs signing. Everywhere else the base
      # configuration signs with an SSH key that Fence read-denies, so turn
      # signing off or the commit fails. ~/Chainguard itself is a personal
      # repository and takes the unsigned path.
      case "$PWD" in
        "$HOME"/Chainguard/?*)
          return 0
          ;;
      esac

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
