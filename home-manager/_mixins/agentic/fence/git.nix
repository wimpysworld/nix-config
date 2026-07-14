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

      fence_env+=(
        "GIT_CONFIG_COUNT=$((git_config_index + 1))"
        "GIT_CONFIG_KEY_$git_config_index=commit.gpgSign"
        "GIT_CONFIG_VALUE_$git_config_index=false"
      )
    }

    setup_fence_git
  '';
}
