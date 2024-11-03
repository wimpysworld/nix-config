#!/usr/bin/env bash
set -eou pipefail

if [ $# -eq 0 ]; then
  deadnix --edit
  statix fix
  nixfmt --verify .
else
  deadnix --edit "$@"
  for target in "$@"; do
    statix fix -- "$target"
  done
  nixfmt --verify "$@"
fi
