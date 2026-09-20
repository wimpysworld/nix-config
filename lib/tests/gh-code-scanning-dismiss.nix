{ pkgs }:
let
  stubBackend = pkgs.writeShellApplication {
    name = "gh-code-scanning-dismiss-gh";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      : "''${GH_CODE_SCANNING_DISMISS_STUB_DIR:?}"
      if [[ $# -eq 4 && $1 == auth && $2 == token && $3 == --hostname && $4 == github.com ]]; then
        printf 'call\n' >> "''${GH_CODE_SCANNING_DISMISS_STUB_DIR}/auth-calls"
        printf '%s\n' "''${GH_CONFIG_DIR-<unset>}" \
          > "''${GH_CODE_SCANNING_DISMISS_STUB_DIR}/auth-config-dir"
        printf '%s' "''${GH_CODE_SCANNING_DISMISS_STUB_AUTH_TOKEN:-offline-stored-token}"
        exit "''${GH_CODE_SCANNING_DISMISS_STUB_AUTH_STATUS:-0}"
      fi
      if [[ ''${GH_TOKEN-} != "''${GH_CODE_SCANNING_DISMISS_EXPECTED_TOKEN:?}" ]]; then
        exit 91
      fi
      call=$(($(wc -l < "''${GH_CODE_SCANNING_DISMISS_STUB_DIR}/calls") + 1))
      printf 'call\n' >> "''${GH_CODE_SCANNING_DISMISS_STUB_DIR}/calls"
      : > "''${GH_CODE_SCANNING_DISMISS_STUB_DIR}/argv-''${call}"
      input=""
      previous=""
      for argument in "$@"; do
        printf '%s\n' "''${argument}" >> "''${GH_CODE_SCANNING_DISMISS_STUB_DIR}/argv-''${call}"
        if [[ ''${previous} == "--input" ]]; then
          input="''${argument}"
        fi
        previous="''${argument}"
      done
      printf '%s\n' "''${GH_CONFIG_DIR-<unset>}" \
        > "''${GH_CODE_SCANNING_DISMISS_STUB_DIR}/config-dir-''${call}"
      stat -c '%a' "''${GH_CONFIG_DIR}" \
        > "''${GH_CODE_SCANNING_DISMISS_STUB_DIR}/config-mode-''${call}"
      find "''${GH_CONFIG_DIR}" -mindepth 1 -maxdepth 1 -printf . | wc -c \
        > "''${GH_CODE_SCANNING_DISMISS_STUB_DIR}/config-files-''${call}"
      for variable in GH_DEBUG DEBUG HTTP_PROXY HTTPS_PROXY ALL_PROXY NO_PROXY \
        http_proxy https_proxy all_proxy no_proxy SSL_CERT_DIR CURL_CA_BUNDLE \
        REQUESTS_CA_BUNDLE GIT_SSL_CAINFO GIT_SSL_CAPATH NODE_EXTRA_CA_CERTS; do
        if [[ -v ''${variable} ]]; then
          printf '%s=set\n' "''${variable}" >> "''${GH_CODE_SCANNING_DISMISS_STUB_DIR}/environment-''${call}"
        else
          printf '%s=unset\n' "''${variable}" >> "''${GH_CODE_SCANNING_DISMISS_STUB_DIR}/environment-''${call}"
        fi
      done
      printf 'SSL_CERT_FILE=%s\n' "''${SSL_CERT_FILE-<unset>}" \
        >> "''${GH_CODE_SCANNING_DISMISS_STUB_DIR}/environment-''${call}"
      printf 'NIX_SSL_CERT_FILE=%s\n' "''${NIX_SSL_CERT_FILE-<unset>}" \
        >> "''${GH_CODE_SCANNING_DISMISS_STUB_DIR}/environment-''${call}"
      if [[ -n ''${input} ]]; then
        cp -- "''${input}" "''${GH_CODE_SCANNING_DISMISS_STUB_DIR}/request-''${call}"
      fi
      if [[ -r "''${GH_CODE_SCANNING_DISMISS_STUB_DIR}/response-''${call}" ]]; then
        cat "''${GH_CODE_SCANNING_DISMISS_STUB_DIR}/response-''${call}"
      fi
      if [[ -r "''${GH_CODE_SCANNING_DISMISS_STUB_DIR}/status-''${call}" ]]; then
        exit "$(cat "''${GH_CODE_SCANNING_DISMISS_STUB_DIR}/status-''${call}")"
      fi
    '';
  };

  failingEncoder = pkgs.writeShellApplication {
    name = "jq";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      : "''${GH_CODE_SCANNING_DISMISS_JQ_COUNT:?}"
      count=0
      if [[ -r ''${GH_CODE_SCANNING_DISMISS_JQ_COUNT} ]]; then
        count=$(cat "''${GH_CODE_SCANNING_DISMISS_JQ_COUNT}")
      fi
      count=$((count + 1))
      printf '%s\n' "''${count}" > "''${GH_CODE_SCANNING_DISMISS_JQ_COUNT}"
      if [[ ''${count} -eq 2 ]]; then
        exit 73
      fi
      exec ${pkgs.lib.getExe pkgs.jq} "$@"
    '';
  };

  helper = pkgs.callPackage ../../home-manager/_mixins/development/github/gh-code-scanning-dismiss {
    ghBackend = stubBackend;
  };
  encoderFailureHelper =
    pkgs.callPackage ../../home-manager/_mixins/development/github/gh-code-scanning-dismiss
      {
        ghBackend = stubBackend;
        jq = failingEncoder;
      };
  realHelper =
    pkgs.callPackage ../../home-manager/_mixins/development/github/gh-code-scanning-dismiss
      { };
in
pkgs.runCommand "gh-code-scanning-dismiss-tests"
  {
    nativeBuildInputs = [
      pkgs.bash
      pkgs.jq
      pkgs.python3
      pkgs.shellcheck
    ];
  }
  ''
    shellcheck \
      ${../../home-manager/_mixins/development/github/gh-code-scanning-dismiss/gh-code-scanning-dismiss.sh} \
      ${../../home-manager/_mixins/development/github/gh-code-scanning-dismiss/tests.sh}
    GH_CODE_SCANNING_DISMISS_NETWORK_ISOLATED=1 ${pkgs.lib.getExe pkgs.bash} \
      ${../../home-manager/_mixins/development/github/gh-code-scanning-dismiss/tests.sh} \
      ${pkgs.lib.getExe helper} \
      ${pkgs.lib.getExe encoderFailureHelper} \
      ${pkgs.lib.getExe realHelper}
    touch "$out"
  ''
