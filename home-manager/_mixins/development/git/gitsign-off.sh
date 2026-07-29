#!/usr/bin/env bash

# Re-sign the most recent commit and add a sign-off trailer, changing nothing
# else about it. Everything is read from the repository's own Git
# configuration, so the same command works in a personal repository that signs
# with SSH and in a work repository that signs with gitsign.

usage() {
  echo "Usage: gitsign-off [--force]"
  echo
  echo "Re-sign the most recent commit and add a Signed-off-by trailer."
  echo
  echo "  --force    Amend even when HEAD has already been pushed."
  echo "  -h, --help Show this message."
}

force="false"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --force)
      force="true"
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR! Unknown argument: $1" >&2
      usage >&2
      exit 64
      ;;
  esac
done

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "ERROR! This command must be run inside a Git repository." >&2
  exit 1
fi

if ! git rev-parse --verify --quiet HEAD >/dev/null; then
  echo "ERROR! HEAD does not point at a commit yet, so there is nothing to re-sign." >&2
  exit 1
fi

# Read each identity value once. An unset key makes 'git config --get' exit
# non-zero, so the failure is absorbed here and reported below by name.
user_email="$(git config --get user.email || true)"
user_name="$(git config --get user.name || true)"

if [ -z "${user_email}" ]; then
  echo "ERROR! 'user.email' is unset or empty in this repository's Git configuration." >&2
  exit 1
fi

if [ -z "${user_name}" ]; then
  echo "ERROR! 'user.name' is unset or empty in this repository's Git configuration." >&2
  exit 1
fi

# Amending a commit that the upstream branch already contains rewrites
# published history, which then needs a force push. Refuse by default. A
# missing upstream is normal for a local branch, so it is not an error.
if [ "${force}" = "false" ]; then
  upstream="$(git rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null || true)"
  if [ -n "${upstream}" ] && git merge-base --is-ancestor HEAD "${upstream}"; then
    echo "ERROR! HEAD is already reachable from '${upstream}', so it has been pushed." >&2
    echo "Amending it would rewrite published history and need a force push." >&2
    echo "Re-run as 'gitsign-off --force' if that is what you want." >&2
    exit 1
  fi
fi

# The -S flag signs with whatever 'gpg.format' and the matching signing
# program resolve to for this repository, so it covers both the SSH signing
# path and the gitsign x509 path without naming either here.
git commit -S --amend --signoff --no-edit --author="${user_name} <${user_email}>"

echo
# Report the resulting signature so the amend can be seen to have worked.
# Verification depends on local trust configuration, such as an allowed
# signers file, that may be absent, so a failure here is only a warning.
if ! gitsign-verify HEAD; then
  echo "Warning: the amended commit did not verify cleanly. See the report above." >&2
fi
