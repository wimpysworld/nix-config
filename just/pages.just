# Managed by Tailor: just/pages.just

# Preview the Pages site at http://127.0.0.1:18473
pages:
    #!/usr/bin/env bash
    set -e
    if ! command -v miniserve >/dev/null 2>&1; then
        echo "Error: miniserve is not on PATH. Likely causes:" >&2
        echo "  1. The Nix dev shell failed to build. Run nix develop to see the error, for example a stale flake input fixed by nix flake update <input>." >&2
        echo "  2. direnv uses an old or missing cache. Run nix-direnv-reload." >&2
        echo "  3. nix/pages.nix or another Nix file is not added to Git, and flakes ignore untracked files. Run git add on it." >&2
        exit 1
    fi
    site="pages"
    if [ ! -f "${site}/index.html" ]; then
        echo "Error: preview requires \"pages/index.html\". Add that file first." >&2
        exit 1
    fi
    miniserve --index index.html --interfaces 127.0.0.1 --port 18473 "${site}"
