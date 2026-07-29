#!/usr/bin/env bash

# Report whether a commit is correctly signed under the signing configuration
# that applies to its repository. Nothing about the format or the identity is
# assumed here, so the same command works in a personal repository that signs
# with SSH and in a work repository that signs with gitsign.

usage() {
  echo "Usage: gitsign-verify [<commit-ish>]"
  echo
  echo "Report the signature state of a commit, defaulting to HEAD."
}

commit="HEAD"

case "$#" in
  0) ;;
  1)
    case "$1" in
      -h | --help)
        usage
        exit 0
        ;;
      -*)
        echo "ERROR! Unknown argument: $1" >&2
        usage >&2
        exit 64
        ;;
      *)
        commit="$1"
        ;;
    esac
    ;;
  *)
    echo "ERROR! Only one commit may be given." >&2
    usage >&2
    exit 64
    ;;
esac

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "ERROR! This command must be run inside a Git repository." >&2
  exit 1
fi

if ! object="$(git rev-parse --verify --quiet "${commit}^{commit}")"; then
  echo "ERROR! '${commit}' does not resolve to a commit in this repository." >&2
  exit 1
fi

# Git treats an unset 'gpg.format' as openpgp, so mirror that default rather
# than reporting the setting as missing.
signing_format="$(git config --get gpg.format || true)"
if [ -z "${signing_format}" ]; then
  signing_format="openpgp"
fi
signing_program="$(git config --get "gpg.${signing_format}.program" || true)"

# One log call collects every field. The unit separator keeps the values apart
# because names, subjects, and signer identities may all contain spaces.
separator=$'\x1f'
IFS="${separator}" read -r subject author committer status signer key trust signoff < <(
  git log -1 \
    --format="%s%x1f%an <%ae>%x1f%cn <%ce>%x1f%G?%x1f%GS%x1f%GK%x1f%GT%x1f%(trailers:key=Signed-off-by,valueonly,separator=%x2c%x20)" \
    "${object}"
)

# The codes come from the %G? placeholder documented in git-log(1).
case "${status}" in
  G) description="good signature" ;;
  B) description="bad signature" ;;
  U) description="good signature with unknown validity" ;;
  X) description="good signature, but the key has expired" ;;
  Y) description="good signature, but it was made by an expired key" ;;
  R) description="good signature, but it was made by a revoked key" ;;
  E) description="the signature could not be checked" ;;
  N) description="no signature" ;;
  *) description="unrecognised signature status" ;;
esac

echo "Commit:        $(git rev-parse --short "${object}") ${subject}"
echo "Author:        ${author}"
echo "Committer:     ${committer}"
if [ -n "${signing_program}" ]; then
  echo "Format:        ${signing_format}, signed with ${signing_program}"
else
  echo "Format:        ${signing_format}"
fi
echo "Signature:     ${status}, ${description}"
if [ -n "${signer}" ]; then
  echo "Signer:        ${signer}"
fi
if [ -n "${key}" ]; then
  echo "Key:           ${key}"
fi
# Git prints a trust level of 'undefined' even when nothing was signed, so
# only report it when a signature exists.
if [ -n "${trust}" ] && [ "${status}" != "N" ]; then
  echo "Trust:         ${trust}"
fi
if [ -n "${signoff}" ]; then
  echo "Signed-off-by: ${signoff}"
else
  echo "Signed-off-by: absent"
  echo "Warning: this commit has no Signed-off-by trailer." >&2
fi

case "${status}" in
  G)
    exit 0
    ;;
  U)
    # An x509 signature made by gitsign commonly lands here, because Git can
    # confirm the signature yet cannot judge the certificate as fully valid.
    echo "Warning: the signature is good, but its validity is unknown." >&2
    exit 0
    ;;
  *)
    echo "ERROR! The signature on '${commit}' is not good: ${description}." >&2
    exit 1
    ;;
esac
