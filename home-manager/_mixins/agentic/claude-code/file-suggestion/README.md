# Claude Code Fuzzy Finder: Why It's Dogshit

Findings for Claude Code CLI 2.1.126 (binary: `/nix/store/280qb7zhg6i2zg9q7g8b2fcmqm92j283-claude-code-2.1.126/bin/.claude-wrapped`). Symbols and behaviour quoted below come from grepping the bun-compiled binary; identifiers are minified, semantics are unambiguous.

## TL;DR

- The `@` picker uses a hand-rolled, in-process **subsequence matcher** (not fzf/fzy/fuzzysort), capped at **15 results**, indexed once from `git ls-files` (with ripgrep `--files` as fallback).
- The query must be a **left-to-right ordered subsequence of the lowercased path**. There is no substring fallback, no transposition tolerance, and no token splitting; "xyzpack" cannot match `packages/xyz-project/package.json`.
- The index is **gated on `git ls-files`**. Untracked files, `.gitignored` files, files from `/add-dir`/`additionalDirectories`, files in nested submodules, and files created mid-session are routinely missing or stale.
- Scoring penalises long paths and bumps results containing the literal word `test`. There is no recency, no MRU, no editor-active boost, no path-segment weighting beyond a small word-boundary bonus.
- Anthropic shipped a `fileSuggestion` escape hatch in `settings.json` that runs an arbitrary shell command per keystroke. Pipe `fd | fzf --filter` and the picker becomes usable. → recommended fix.

### The fix (copy-paste, no Nix required)

Requires `fd` and `fzf` on `PATH`. Two files, one chmod:

`~/.claude/settings.json` (merge into existing):

```json
{
  "fileSuggestion": {
    "type": "command",
    "command": "~/.claude/file-suggestion.sh"
  }
}
```

`~/.claude/file-suggestion.sh`:

```bash
#!/usr/bin/env bash
# Replace Claude Code's broken @ picker with fd + fzf scoring.
set -euo pipefail

read -r INPUT || INPUT=''
QUERY=$(printf '%s' "$INPUT" | sed -n 's/.*"query"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')

cd "${CLAUDE_PROJECT_DIR:-$PWD}" || exit 0

if [[ -z "$QUERY" ]]; then
  fd --type f --hidden --follow --color never --changed-within 7d 2>/dev/null | head -15
  exit 0
fi

fd --type f --hidden --follow --color never 2>/dev/null \
  | fzf --filter "$QUERY" \
  | head -15
```

```bash
chmod +x ~/.claude/file-suggestion.sh
```

Optional but recommended: export `USE_BUILTIN_RIPGREP=0` so Claude Code uses your system `rg`. Restart Claude Code. Picker now ranks by proper fuzzy score, follows symlinks, and respects `.gitignore`/`.fdignore`/`.ignore`.

## Symptoms

Concrete failure modes documented in upstream issues, Reddit threads, and the binary itself:

- **No substring fallback.** Typing `7-5` finds anything where `7` then `-` then `5` appear in order — even if a file literally named `7-5.something` exists. (#20065)
- **Word-fragment queries die.** `@xyzpack` won't surface `packages/xyz-project/package.json`; the picker requires a contiguous subsequence, so the user has to remember path order. (#20065 comments, #11307)
- **Top-15 hard cap.** `VT6 = 15` in the binary. Large repos lose the right answer below the fold; no pagination. (algorithm in `qj$.search`)
- **Untracked-file blackhole.** `git ls-files` is the primary source. New, unstaged, or `.gitignore`-excluded files don't appear at all. (#40082, #45012, #36647, #14904)
- **Stale prefix index.** Files created mid-session show up in the unfiltered `@` dropdown but not in prefix-filtered queries until the session restarts. (#53517)
- **`additionalDirectories` / `/add-dir` not searched.** The picker only fuzzy-matches inside the git root; added directories require typing the full path. (#52092, #7412)
- **Monorepo bleed.** Launching from `apps/foo/` searches the whole monorepo from the git root; sibling apps pollute every result list. (#54617)
- **Filename-only display.** Results show bare filenames; multiple `index.ts` are indistinguishable. (#51892, #17793)
- **`.ignore` / `.rgignore` / `.claudeignore` ignored.** Only `.gitignore` participates, and only via `git ls-files`. (#30176, #45691)
- **Hidden directories indexed.** `.git/objects/`, `~/.claude/skills/*/node_modules`, `.venv` end up in the index, causing 2-5 s freezes. (#11673)
- **Diacritic-insensitive matching missing.** `cafe` doesn't match `café`. (#33341, closed)
- **CJK / IME input bypasses the script entirely.** Even the custom `fileSuggestion` command isn't invoked when typing non-ASCII. (#23911)
- **Bundled ripgrep crashes on 16 KB-page kernels (Apple Silicon, some Linux).** `<jemalloc>: Unsupported system page size`; picker silently returns nothing. Workaround `USE_BUILTIN_RIPGREP=0`. (#11307, #7661)
- **`respectGitignore: false` silently ignored** in some 2.0.x and 2.1.x releases. (#14904)
- **VS Code extension picker** had a 5-10 s regression in 2.1.27-2.1.31, partially fixed in 2.1.32+. (#22434, #22446, #22950)
- **No fuzzy-search keybind to navigate results**, no preview pane, no multi-select.

## Root cause analysis

Reverse-engineered from the v2.1.126 binary at `/nix/store/280qb7zhg6i2zg9q7g8b2fcmqm92j283-claude-code-2.1.126/bin/.claude-wrapped`. All quoted code is minified JS embedded in the bun binary.

### The matcher: bespoke subsequence scorer in class `qj$`

```js
class qj${
  paths=[]; lowerPaths=[]; charBits=new Int32Array(0);
  pathLens=new Uint16Array(0); topLevelCache=null; readyCount=0;
  // ...
  search(H, $) {
    if ($ <= 0) return [];
    if (H.length === 0) { /* return cached top-level dirs */ }
    let q = H !== H.toLowerCase();              // case-sensitive iff query mixed-case
    let K = q ? H : H.toLowerCase();
    let _ = Math.min(K.length, 64);             // queries truncated at 64 chars
    let A = Array(_), z = 0;
    for (let G = 0; G < _; G++) {               // build query bitset
      let W = K.charAt(G); A[G] = W;
      let Z = W.charCodeAt(0);
      if (Z >= 97 && Z <= 122) z |= 1 << (Z - 97);
    }
    // ... main loop:
    H: for (let G = 0; G < X; G++) {
      if ((w[G] & z) !== z) continue;           // bitset prefilter (a-z only)
      let W = q ? M[G] : D[G];
      let Z = W.indexOf(A[0]); if (Z === -1) continue;
      // walk subsequence left-to-right
      for (let C = 1; C < _; C++) {
        if (Z = W.indexOf(A[C], N + 1), Z === -1) continue H;
        let F = Z - N - 1;
        if (F === 0) V += 4;                    // adjacent: +4
        else v += 3 + F * 1;                    // gap penalty: -3 -F
        N = Z;
      }
      // base score
      let R = _ * 16 + V - v;
      R += Yc7(I, hA8[0], !0);                  // word-boundary bonus on first hit
      for (let C = 1; C < _; C++) R += Yc7(I, hA8[C], !1);
      R += Math.max(0, 32 - (S >> 2));          // shorter paths preferred
      // ... keep top-$ results
    }
    // tie-break / normalise:
    P[G] = { path: W, score: W.includes("test") ? Math.min(Z*1.05, 1) : Z };
  }
}
function Yc7(H, $, q) {
  if ($ === 0) return q ? 8 : 0;
  let K = H.charCodeAt($ - 1);
  if (wn_(K)) return 8;                         // / \ - _ . space → +8
  if (jn_(K) && Xn_(H.charCodeAt($))) return 6; // camelCase boundary → +6
  return 0;
}
```

What this proves:

- **It is a subsequence matcher**, equivalent in spirit to early Sublime/CtrlP, but without the bigram, transposition, or BM25 refinements that fzf/fzy/fuzzysort have iterated on for a decade. There is no Smith-Waterman, no bitap, no Levenshtein. Reordered or split queries fail outright.
- **Lowercased** unless the query has any uppercase character, in which case matching becomes case-sensitive (smartcase). Diacritics are not normalised.
- **Char-class bitset** limited to `a-z`; non-ASCII characters bypass the prefilter and search every path linearly.
- **Result cap is hard-coded** at `VT6 = 15`.
- **`test` boost is a special case**, not a general scoring rule. There is no concept of "open in IDE", recency, or frecency.
- **Scoring favours short paths** via `32 - (pathLen >> 2)`, which is why deep monorepo paths systematically rank below shorter siblings even when they're the better match.

### The index: `git ls-files` first, ripgrep fallback

```js
async function vn_(H, $, q) {
  let K = await Gn_(H, $, q);                   // git ls-files --recurse-submodules
  if (K !== null) return K;
  // ripgrep fallback
  let M = ["--files","--follow","--hidden",
           "--glob","!.git/","--glob","!.svn/", "--glob","!.hg/",
           "--glob","!.bzr/","--glob","!.jj/","--glob","!.sl/"];
  if (!q) M.push("--no-ignore-vcs");
  Y = await jo(M, A, $);
}
```

- Inside a git repo: `git -c core.quotepath=false ls-files --recurse-submodules`. **Untracked files, gitignored files, anything not committed do not appear.**
- Outside a git repo: ripgrep `--files --hidden`, optionally with `--no-ignore-vcs` if `respectGitignore=false`.
- Index is rebuilt on a 5-second cooldown (`Nn_ = 5000`) **and** when the git index `mtime` changes. New files in non-git directories rely on filesystem signature comparison, which has the staleness bug in #53517.
- `.ignore`, `.rgignore`, `.fdignore`, `.claudeignore` are not consulted.

### The dispatch path

```js
async function zcH(H, $, q = !1) {
  if (h6()) return En_($);                                    // remote / VS Code RPC
  if (x6().fileSuggestion?.type === "command")
    return (await hT6(...)).slice(0, VT6).map(SA8);            // user override
  if ($ === "" || $ === "." || $ === "./") {                  // empty query
    let _ = await yn_();                                       // readdir of cwd
    return _.slice(0, VT6).map(SA8);
  }
  Kj$(H);                                                      // refresh index
  let Y = H.fileIndex ? kn_(H.fileIndex, A) : [];              // qj$.search
  return Y;
}
```

- **Empty query** (`@`) returns `readdir(cwd)`, sliced to 15 — explains why "I just see the same handful of top-level files".
- **Custom command** is the only way to bypass the in-process matcher.
- **Remote / VS Code mode** (`En_`) RPCs to the editor's file index, which has its own bugs (#22211, #22446, #22434).

## Community reports

Loudest signal first.

| Issue | State | One-line summary |
|-------|-------|------------------|
| [#20065](https://github.com/anthropics/claude-code/issues/20065) | closed | "Implement fuzzy file search for `@` symbol file mentions" — request for fzf-style matching. Closed, never properly implemented. |
| [#8530](https://github.com/anthropics/claude-code/issues/8530) | closed | "Improve `@` file search command for large repos" — 3-5 s per keystroke; comment: "the experience in OpenCode (where they use fuzzysearch) is both faster and more accurate". |
| [#11673](https://github.com/anthropics/claude-code/issues/11673) | closed (dup) | "@ file autocomplete shows .git/objects and dependency directories causing 2-5 s delays". |
| [#11307](https://github.com/anthropics/claude-code/issues/11307) | closed | "File fuzzy matcher incomplete suggestions for nested directories" — bundled ripgrep crashes on 16 KB-page kernels; workaround `USE_BUILTIN_RIPGREP=0`. |
| [#9570](https://github.com/anthropics/claude-code/issues/9570) | closed | "Fuzzy File Search Fails After `@` Input" — `@trackacctabc` returns nothing in Claude Code; Codex finds the file. |
| [#7661](https://github.com/anthropics/claude-code/issues/7661) | closed | "File Picker Fails to List Complete Directory Contents" — bundled `rg` rejected `--ripgrep` flag, picker silently empty. |
| [#54617](https://github.com/anthropics/claude-code/issues/54617) | open | "Limit @ file picker scope to working directory in monorepo" — sibling apps pollute every search. |
| [#52092](https://github.com/anthropics/claude-code/issues/52092) | open | "@ file picker should support fuzzy filename search in additionalDirectories". |
| [#53517](https://github.com/anthropics/claude-code/issues/53517) | open | "Newly created files invisible until session restart" — prefix index goes stale. |
| [#51892](https://github.com/anthropics/claude-code/issues/51892) | open | "File paths not shown in search results, making disambiguation hard". |
| [#45691](https://github.com/anthropics/claude-code/issues/45691) | open | "Filter @ mention file suggestions via settings or `.claudeignore`". |
| [#45012](https://github.com/anthropics/claude-code/issues/45012) | closed | "@-completion no longer suggests gitignored files since v2.1.94" — regression; explicit knowledge-base use case raised. |
| [#36647](https://github.com/anthropics/claude-code/issues/36647) | open | ".gitignored files excluded from @ picker" — breaks data/notes workflows. |
| [#30176](https://github.com/anthropics/claude-code/issues/30176) | open | ".ignore / .rgignore are not respected by file picker". |
| [#23287](https://github.com/anthropics/claude-code/issues/23287) | open | "File autocomplete suggestions disappear when navigating subdirectories". |
| [#22434](https://github.com/anthropics/claude-code/issues/22434) | closed | "Severe file picker performance regression (VS Code Extension)" — 5-10 s per keystroke in 2.1.27-2.1.31. |
| [#22737](https://github.com/anthropics/claude-code/issues/22737) | open | "fileSuggestion custom command not working" — query never passed to script in some configurations. |
| [#23911](https://github.com/anthropics/claude-code/issues/23911) | open | "fileSuggestion command not invoked when typing non-ASCII (CJK) characters". |
| [#14904](https://github.com/anthropics/claude-code/issues/14904) | open | "respectGitignore in file picker setting ignored in 2.0.75". |
| [#7412](https://github.com/anthropics/claude-code/issues/7412) | open | "@ mentions don't work with additional directories included via /add-dir". |

Representative quotes:

> "Has anyone found a workaround for a bug where claude code's @ mentioning of files and subsequently its fuzzy searching is completely broken? It seems like after typing @ it'll suggest files at the top level, but if I type anything in to fuzzy search for a file (either at the top-level or somewhere further down the file tree), no file results show up. In case you're thinking 'wait doesn't that render claude code completely useless', the answer is yes."  
> — [r/ClaudeCode, 2025-09-16](https://www.reddit.com/r/ClaudeCode/comments/1nii13n/fuzzy_file_searching_has_been_broken_for_like_a/)

> "Using cc in a large monorepo - not sure when it happened but it seems like the file picker (@) now seems to be indexing node modules and that's caused it to become incredibly slow. I've tried a few things - .claudeignore, denying reads to node modules etc but nothing has worked. Claude code itself has not managed to figure this out either btw, ha."  
> — [r/ClaudeAI](https://www.reddit.com/r/ClaudeAI/comments/1po0tb9/cc_slow_file_picker_due_to_node_modules/)

> "I'd like to type @xyzpack (a bit of the path + a bit of the file name) to narrow down the results. I think with the current finder, the search string still must be a connected substring of the path string. But with your script it works."  
> — [@gruhn on #20065](https://github.com/anthropics/claude-code/issues/20065)

> "The default `@` file matcher was always disappointing me, being used to superior options like fzf. It was also not suggesting stuff from gitignored or symlinked folders, which was annoying as hell."  
> — [r/ClaudeAI, 2025-12-19](https://www.reddit.com/r/ClaudeAI/comments/1pqlcyz/custom_file_picker_with_fzf_superior_fuzzy/)

## Workarounds available today

### 1. Replace the picker with `fd | fzf` via `fileSuggestion`

This is the only fix that addresses the matching algorithm. Documented at <https://docs.claude.com/en/docs/claude-code/settings>. The picker calls the script on every keystroke; the script receives `{"query": "..."}` on stdin and must emit up to 15 newline-separated paths.

`~/.claude/settings.json`:

```json
{
  "fileSuggestion": {
    "type": "command",
    "command": "~/.claude/file-suggestion.sh"
  }
}
```

`~/.claude/file-suggestion.sh` (tools already on PATH for Martin: `/home/martin/.nix-profile/bin/{fd,fzf,rg,jq}`):

```bash
#!/usr/bin/env bash
# Custom @ file picker: fd to enumerate, fzf to score.
# - Uses fd for speed (parallel walker, native gitignore + .ignore + .fdignore).
# - fzf --filter performs proper fuzzy scoring (Smith-Waterman-ish, with
#   bigram bonuses, word-boundary boosts, deep-path penalty).

set -euo pipefail

# Avoid jq dependency: extract the query field with a tolerant sed.
read -r INPUT || INPUT=''
QUERY=$(printf '%s' "$INPUT" | sed -n 's/.*"query"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"
cd "$PROJECT_DIR" || exit 0

if [[ -z "$QUERY" ]]; then
  # Empty query: most-recently-modified files, newest first.
  fd --type f --hidden --follow --color never --changed-within 7d 2>/dev/null \
    | head -15
  exit 0
fi

fd --type f --hidden --follow --color never 2>/dev/null \
  | fzf --filter "$QUERY" \
  | head -15
```

```bash
chmod +x ~/.claude/file-suggestion.sh
```

Notes:

- `.fdignore` is per-project; use it to exclude generated dirs without touching `.gitignore`.
- For Nix-style profiles where `fd` is not on Claude Code's PATH, hard-code absolute paths (`/home/martin/.nix-profile/bin/fd`) or prepend PATH inside the script.
- Symlinked directories are followed (`--follow`); drop that flag if it pulls in too much.
- The 15-result cap is enforced by Claude Code regardless. Trust `fzf`'s ranking; never sort by name.

### 2. Project-scoped variant: drop the script in the repo

Set `fileSuggestion.command` to `.claude/file-suggestion.sh` in `.claude/settings.json`. Useful for monorepo subpaths where you want each app to scope its picker to its own subtree (#54617):

```bash
#!/usr/bin/env bash
cd "${CLAUDE_PROJECT_DIR:-$PWD}/apps/$(basename "$PWD")" 2>/dev/null \
  || cd "${CLAUDE_PROJECT_DIR:-$PWD}"
fd --type f --hidden --follow . \
  | fzf --filter "$(sed -n 's/.*"query"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')" \
  | head -15
```

### 3. Built-in knobs (without replacing the matcher)

These do not fix the algorithm, but they reduce the worst symptoms.

- `respectGitignore: false` in `settings.json` (or `/config`): include gitignored files. Buggy in some versions (#14904); confirm by typing `@` and inspecting `~/.claude.json` afterwards.
- `permissions.additionalDirectories`: extend the picker beyond cwd. Note fuzzy search inside those dirs is broken (#52092).
- Environment variables relevant to the picker:
  - `USE_BUILTIN_RIPGREP=0` — skips the bundled `rg` and uses the system one. Required on 16 KB-page kernels; harmless elsewhere when system `rg` is present.
- `/add-dir` to register an extra root in-session.

### 4. Sidestep the picker entirely

- Drag-and-drop a file into the terminal; most terminals paste an absolute path that Claude Code recognises.
- Pipe a list into the prompt: ``$(fzf -m | xargs -I{} echo "@{}")``. Crude but reliable.
- Use the `Read` tool by name and let Claude search via `Glob`/`Grep` rather than mentioning files inline.
- Editor pickers — Telescope, fzf-lua, Snacks.nvim — copy paths to the system clipboard, then paste with `@`.

### 5. MCP servers

There is no canonical "better picker" MCP server. The picker reads from a process-local index, not from MCP. An MCP server can expose `Read` and `Glob` for files outside the workspace, but it cannot replace the `@`-completion UI. The escape hatch is `fileSuggestion`, full stop.

## Recommended path forward

Ranked for Martin's situation (Linux, Nix-managed home, fd/fzf/rg/jq already in `~/.nix-profile/bin`).

1. **Adopt `fileSuggestion` with `fd | fzf`** (workaround 1). Highest impact, ten-line script, reversible. Trade-off: shells out per keystroke, so latency is bounded by `fd` start-up (~5-10 ms) plus fzf scoring; on this hardware that's still well under the current built-in matcher's worst case. Keep the script in the home-manager mixin so it tracks across hosts.
2. **Manage the script declaratively in this flake.** Drop it under `home-manager/_mixins/claude-code/` (or wherever Claude Code config lives) using `pkgs.writeShellApplication` so `runtimeInputs = [ pkgs.fd pkgs.fzf ]` and shellcheck validates it. Wire it into `home.file.".claude/file-suggestion.sh"` and add the `fileSuggestion` block to `~/.claude/settings.json` via the existing claude-code mixin. Trade-off: one more moving part in the config, but it brings the picker behaviour under version control.
3. **Set `USE_BUILTIN_RIPGREP=0`** in the Claude Code wrapper (already a Nix-wrapped derivation). System `rg` is on PATH from `pkgs.ripgrep`, so this is free reliability. Trade-off: none worth mentioning.
4. **File a bug or +1 the loudest open issues** (#54617 monorepo scope, #52092 additionalDirectories fuzzy, #51892 path display, #53517 stale index). Trade-off: low-effort, signals demand, but Anthropic's track record on these is poor — see closure of #20065 without a real fix.
5. **Wait for an upstream rewrite.** No public roadmap commits to a real fuzzy matcher. The 2.1.94 changelog claimed "improved fuzzy matching" yet shipped a regression that excluded gitignored files (#45012). Don't bank on this.
6. **Switch to a competitor for `@` workflows** (OpenCode, Codex, Aider). Trade-off: nuclear option, breaks too many other Claude Code-specific habits to recommend.

→ Do (1) + (2) + (3) together; cost is one mixin and a shell script, payoff is the picker stops being painful.

## References

### Source code (local Claude Code 2.1.126 binary)

- `/nix/store/280qb7zhg6i2zg9q7g8b2fcmqm92j283-claude-code-2.1.126/bin/.claude-wrapped` — bun-compiled ELF; `qj$.search`, `vn_`, `Gn_`, `zcH`, `Yc7`, `wn_`, `jn_`, `Xn_` cited above. `VT6 = 15` result cap, `Nn_ = 5000` ms cache cooldown, `_ = Math.min(K.length, 64)` query truncation.
- Settings schema string in same binary: `"Custom file suggestion configuration for @ mentions"`, `"Whether file picker should respect .gitignore files (default: true). Note: .ignore files are always respected"` (the latter is a lie per #30176).

### Official docs

- <https://docs.claude.com/en/docs/claude-code/settings> — `fileSuggestion`, `respectGitignore`, `permissions.additionalDirectories`.
- <https://gist.github.com/mculp/c082bd1e5a439410158974de90c89db7> — third-party annotated settings.json reference (v2.1.104, April 2026).

### GitHub issues (anthropics/claude-code)

- <https://github.com/anthropics/claude-code/issues/20065> — fuzzy search request, closed without fix.
- <https://github.com/anthropics/claude-code/issues/8530> — large-repo perf, closed.
- <https://github.com/anthropics/claude-code/issues/11673> — .git/objects and dep dirs in index.
- <https://github.com/anthropics/claude-code/issues/11307> — bundled rg + 16 KB pages.
- <https://github.com/anthropics/claude-code/issues/9570> — fuzzy returns nothing.
- <https://github.com/anthropics/claude-code/issues/7661> — picker empty due to bundled rg.
- <https://github.com/anthropics/claude-code/issues/54617> — monorepo scope.
- <https://github.com/anthropics/claude-code/issues/52092> — additionalDirectories fuzzy.
- <https://github.com/anthropics/claude-code/issues/53517> — stale prefix index.
- <https://github.com/anthropics/claude-code/issues/51892> — paths missing from results.
- <https://github.com/anthropics/claude-code/issues/45691> — .claudeignore for picker.
- <https://github.com/anthropics/claude-code/issues/45012> — gitignored regression.
- <https://github.com/anthropics/claude-code/issues/36647> — gitignore exclusion.
- <https://github.com/anthropics/claude-code/issues/30176> — .ignore not respected.
- <https://github.com/anthropics/claude-code/issues/23287> — autocomplete vanishes in subdirs.
- <https://github.com/anthropics/claude-code/issues/22434> — VS Code regression.
- <https://github.com/anthropics/claude-code/issues/22737> — fileSuggestion broken in some modes.
- <https://github.com/anthropics/claude-code/issues/23911> — CJK / IME bypass.
- <https://github.com/anthropics/claude-code/issues/14904> — respectGitignore ignored.
- <https://github.com/anthropics/claude-code/issues/7412> — /add-dir not searched.

### Community workarounds

- <https://www.reddit.com/r/ClaudeAI/comments/1pqlcyz/custom_file_picker_with_fzf_superior_fuzzy/> — original rg+fzf write-up.
- <https://thayto.com/en/blog/claude-code-faster-file-suggestion> — same approach, blog form.
- <https://gist.github.com/cicorias/b05390abb6a0582930da4c9d9734cdab> — gist, rg+fzf.
- <https://gist.github.com/kvirani/bf36d4e4236e57d617c6240096a0fc7d> — fd+fzf for non-git workspaces (UE5, Perforce); explains `.fdignore` vs `.ignore` vs `.claudeignore`.
- <https://github.com/gutyoh/claude-code-config> — reusable repo with auto-installer and Windows port.
- <https://www.reddit.com/r/ClaudeAI/comments/1po0tb9/cc_slow_file_picker_due_to_node_modules/> — node_modules slowdown report.
- <https://www.reddit.com/r/ClaudeCode/comments/1nii13n/fuzzy_file_searching_has_been_broken_for_like_a/> — fuzzy search broken thread.
