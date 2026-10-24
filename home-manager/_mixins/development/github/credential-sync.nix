# The GitHub module and `mint-tokens` both import this file, so they share
# one scope list, one marker path, and one `gh-credential-sync` derivation.
{
  config,
  lib,
  pkgs,
}:
let
  # The OAuth token `gh` stores never expires and has no refresh token, so
  # nothing refreshes it. The scopes `gh` asked for at login are the one thing
  # that goes stale, and only a browser device flow can add one. Every scope a
  # command in this configuration needs is listed here. `gh-credential-sync`
  # compares the list with the live token and leaves a marker that the shell
  # prompt reports, so a missing scope surfaces without a network call at shell
  # start.
  requiredScopes = [
    "gist"
    "project"
    "read:org"
    "repo"
    "workflow"
  ];
  stateDir = "${config.xdg.stateHome}/gh";
  missingScopesFile = "${stateDir}/missing-scopes";
  # Nix reads GitHub tokens from `access-tokens`, never from `GH_TOKEN`, so
  # the sync also writes the token into a file that the user `nix.conf`
  # includes. `!include` ignores a missing file, so a host that has never run
  # the sync loses nothing.
  nixAccessTokensFile = "${config.xdg.configHome}/nix/access-tokens.conf";
  # The sync exits with this status when it cannot check the token, so that a
  # caller can tell a locked keyring or a network failure from a checked token.
  uncheckedExitStatus = 75;

  package = pkgs.writeShellApplication {
    name = "gh-credential-sync";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gh
      pkgs.jq
    ];
    text = ''
      required=(${lib.escapeShellArgs requiredScopes})
      state_dir=${lib.escapeShellArg stateDir}
      missing_file=${lib.escapeShellArg missingScopesFile}
      tokens_file=${lib.escapeShellArg nixAccessTokensFile}

      # Read the stored credential, never an inherited environment copy.
      unset GH_TOKEN GITHUB_TOKEN GH_ENTERPRISE_TOKEN GITHUB_ENTERPRISE_TOKEN
      mkdir -p "$state_dir" "$(dirname "$tokens_file")"

      # With `--json`, `gh auth status` exits 0 in every case, so the result
      # comes from the JSON. No github.com entry means that `gh` has no login.
      status_json="$(gh auth status --hostname github.com --active --json hosts)"
      entry="$(jq -c '.hosts["github.com"] // [] | map(select(.active)) | first // empty' <<< "$status_json")"
      if [[ -z $entry ]]; then
        echo "gh-credential-sync: not logged in to github.com" >&2
        printf 'not logged in\n' > "$missing_file"
        exit 0
      fi

      # A configured account whose token `gh` cannot read reports the token
      # source "default". That happens when the keyring is locked or not
      # running, for example before desktop login. Leave both files alone
      # and let the next run after login do the work.
      if [[ "$(jq -r '.tokenSource' <<< "$entry")" == default ]]; then
        echo "gh-credential-sync: the keyring is locked or unavailable; nothing changed" >&2
        exit ${toString uncheckedExitStatus}
      fi

      if [[ "$(jq -r '.state' <<< "$entry")" != success ]]; then
        error="$(jq -r '.error // "unknown error"' <<< "$entry")"
        # GitHub rejects a revoked or expired token with HTTP 401. Any other
        # error, such as a network failure, can pass, so it changes nothing.
        if [[ $error == "HTTP 401"* ]]; then
          echo "gh-credential-sync: github.com rejected the stored token" >&2
          printf 'not logged in\n' > "$missing_file"
          exit 0
        fi
        echo "gh-credential-sync: cannot check the token: $error" >&2
        exit ${toString uncheckedExitStatus}
      fi

      mapfile -t missing < <(
        jq -r '[(.scopes // "") | scan("[^, ]+")] as $have | $ARGS.positional - $have | .[]' \
          --args "''${required[@]}" <<< "$entry"
      )
      if (( ''${#missing[@]} > 0 )); then
        printf '%s\n' "''${missing[@]}" > "$missing_file"
        echo "gh-credential-sync: token lacks scopes: ''${missing[*]}" >&2
      else
        rm -f "$missing_file"
      fi

      token="$(gh auth token --hostname github.com)"
      tmp="$(mktemp "$tokens_file.XXXXXX")"
      printf 'access-tokens = github.com=%s\n' "$token" > "$tmp"
      chmod 600 "$tmp"
      mv "$tmp" "$tokens_file"
    '';
  };
in
{
  inherit
    missingScopesFile
    nixAccessTokensFile
    package
    requiredScopes
    uncheckedExitStatus
    ;
}
