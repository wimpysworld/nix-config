#!/usr/bin/env bash
# Replace Claude Code's broken @ picker with fd + fzf scoring.
#
# Claude Code's built-in fuzzy finder is a bespoke subsequence matcher capped
# at 15 results, indexed via `git ls-files`. It misses untracked files and
# fails on word-fragment queries. This script is wired in via the
# `fileSuggestion` escape hatch in settings.json, which receives a JSON
# `{"query": "..."}` blob on stdin and emits up to 15 newline-separated paths.
# fd enumerates fast and respects gitignore plus .ignore and .fdignore;
# fzf --filter performs proper fuzzy scoring with bigram and word-boundary
# bonuses.
#
# `pkgs.writeShellApplication` injects `set -euo pipefail` ahead of this
# source, which bites in two places: `fzf --filter QUERY` exits 1 on zero
# matches, and any pipe into `head -N` triggers SIGPIPE (141) on the upstream
# producer once it has emitted more than N lines. Either failure causes the
# whole script to abort with no output, leaving the picker empty even when
# results were ready. The fix is to capture command output into variables
# rather than streaming through `head`, and to neutralise the expected
# non-zero exits with `|| true`.

# Avoid jq dependency. Extract the query field with a tolerant sed expression
# so the script stays usable even when jq is not on the PATH Claude Code
# inherits.
read -r INPUT || INPUT=''
QUERY=$(printf '%s' "$INPUT" | sed -n 's/.*"query"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')

# Search root: prefer the project directory Claude Code exports, fall back to
# the working directory if it is not set.
cd "${CLAUDE_PROJECT_DIR:-$PWD}" || exit 0

# Print the first 15 lines of stdin without closing the upstream pipe early.
# `head -15` closes its input as soon as the cap is reached and SIGPIPEs the
# producer; under `pipefail` that becomes a script-wide exit 141. `awk`
# instead consumes the full stream and only prints the first 15 lines, so
# the producer always exits cleanly.
take15() {
  awk 'NR<=15'
}

if [[ -z "$QUERY" ]]; then
  # Empty query (`@` with no characters typed): prefer files changed in the
  # last 7 days; fall back to the full tree when the recency filter would
  # otherwise return nothing (fresh checkouts, long-idle projects). Both
  # branches go through `take15` to enforce the 15-result cap.
  RECENT=$(fd --type f --hidden --follow --color never --changed-within 7d 2>/dev/null || true)
  if [[ -z "$RECENT" ]]; then
    RECENT=$(fd --type f --hidden --follow --color never 2>/dev/null || true)
  fi
  printf '%s\n' "$RECENT" | take15
  exit 0
fi

# `fzf --filter` exits 1 when no matches are found; `|| true` keeps that from
# tripping `errexit`. `fd` output is captured into a variable so that the
# `head`-style trim downstream does not SIGPIPE the walker. When fzf returns
# zero matches `$RANKED` is empty; printing it would emit a blank result line
# the picker shows as a phantom row, so skip the print in that case.
ALL=$(fd --type f --hidden --follow --color never 2>/dev/null || true)
RANKED=$(printf '%s\n' "$ALL" | fzf --filter "$QUERY" 2>/dev/null || true)
if [[ -n "$RANKED" ]]; then
  printf '%s\n' "$RANKED" | take15
fi
