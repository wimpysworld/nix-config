# Simple CLI design

Use a one-shot CLI to read arguments, do work, print results, and exit without a full-screen UI.
This reference draws on [clig.dev](https://clig.dev) and the [12-Factor CLI](https://medium.com/@jdxcode/12-factor-cli-apps-dd3c227a0e46).
Other sources are POSIX.1-2017 utility conventions, GNU standards, XDG, BSD `sysexits.h`, and established CLI tools.
All reference paths are relative to the skill root.

## Contents

- [Foundational principles](#foundational-principles)
- [Input and arguments](#input-and-arguments)
- [Output design](#output-design)
- [Exit codes](#exit-codes)
- [Error messages](#error-messages)
- [Help and discoverability](#help-and-discoverability)
- [Subcommands](#subcommands)
- [Shell integration](#shell-integration)
- [Configuration and state](#configuration-and-state)
- [Performance and signals](#performance-and-signals)
- [Compatibility](#compatibility)
- [Distribution, updates, and telemetry](#distribution-updates-and-telemetry)
- [Naming](#naming)
- [Examples to study](#examples-to-study)
- [Final checklist](#final-checklist)

## Foundational principles

- Default to readable output, with explicit machine formats such as `--json`, `--plain`, or `-o yaml`.
- Preserve stdin/stdout/stderr, exit codes, signals, and line-based composition.
- Supply help, examples, typo suggestions, and shell completions.
- Give the same flag the same meaning across commands.
- Validate early and report state accurately.
- Use a parser library instead of a custom parser.

Parser choices include Cobra, urfave/cli, Click, Typer, argparse, clap, oclif, picocli, and swift-argument-parser.
Doug McIlroy's composition rule is: "expect the output of every program to become the input to another, as yet unknown, program."

## Input and arguments

### Argument syntax

| Convention | Meaning |
| --- | --- |
| POSIX names | Lowercase, 2-9 characters |
| `-a` | Single alphanumeric option |
| `-abc` | Combined boolean flags, equivalent to `-a -b -c` |
| `-o file` / `-ofile` | Option with argument |
| `--` | End of option parsing |
| Bare `-` | stdin/stdout where appropriate |
| GNU long options | `--verbose`, `--output=foo.txt` |

Give each short option a long form.
Reserve short forms for frequent actions: `-f`/`--file`, `-o`/`--output`, `-v`/`--verbose`, `-q`/`--quiet`, `-h`/`--help`.
Use long-only flags for rare actions.
Choose one meaning for `-f`: tools differ between `--file` and `--force`.
Do not use both meanings within one tool.

### Flags and positional arguments

Prefer flags when positional meaning is unclear.
`heroku fork --from FROMAPP --to TOAPP` is clearer than `heroku fork FROMAPP --app TOAPP`.
clig.dev states: "Two or more args of different types is suspect; three is never good."

### Streams

| Stream | Contract |
| --- | --- |
| stdout | Results, machine-readable when piped |
| stderr | Logs, progress, prompts, errors |
| stdin | Input, including `-` where supported |

If input is required but stdin is an interactive terminal, show help instead of an unexplained wait.

### Interactivity

Prompt only through an available interactive channel, normally a TTY or deliberately opened `/dev/tty`.
For piped input or CI, report the documented non-interactive flag, environment variable, or stdin contract.
There is no universal `--no-input` spelling.
Confirm destructive actions, with a documented `-y`/`--yes` or `-f`/`--force` override.
For severe actions, require typed confirmation such as `--confirm=name-of-thing`.

Never accept secrets through `--password=…`.
Process lists, shell history, `docker inspect`, and logs expose arguments.
Use `--password-file path/to/secret`, `--password-stdin`, an OS keychain, or `git-credential-*` helpers.

## Output design

### Human tables

- Use one record per line.
- Omit ASCII borders that break `wc -l` and `grep` composition.
- Show headers by default, with `--no-headers`.
- Truncate to terminal width, with `--no-truncate`.
- Support `--columns col1,col2`, `--sort col`, and `--filter` where useful.
- Provide `--csv` or `--json` for machines.

### JSON and NDJSON

Use `--json` for structured output.
NDJSON puts one object on each line so that consumers can process incrementally with jq.
For projection options, study kubectl's `-o {wide,json,yaml,name,jsonpath=…,go-template=…,custom-columns=…}`.

### Verbosity

| Option | Behaviour |
| --- | --- |
| `-q` / `--quiet` | Suppress non-essential output, but retain errors |
| `-v` / `--verbose` | More detail |
| `-vv` / `-vvv` | Increasing debug detail |
| `--debug` / `DEBUG=1` | Stack traces, absent by default |

### Progress

Write progress to stderr. Suppress animations on non-TTY output.
Delay progress indicators about 100-200ms to avoid flashes for immediate work.
See Spinners in `references/visual-patterns.md`.
For multi-step work, hide routine logs behind progress and print those logs on failure, as Docker Compose does.

### Colour

In automatic mode, disable colour on non-TTY output, with non-empty `NO_COLOR`, or with `TERM=dumb`.
Support `--no-color` / `--color=never` and `--color={auto,always,never}`.
Use `FORCE_COLOR=1`, `--color=always`, and optional `MYAPP_NO_COLOR` / `MYAPP_FORCE_COLOR` for explicit control.
Follow [no-color.org](https://no-color.org).

Define precedence: explicit CLI flag, tool-specific environment, general environment, then automatic detection.
At the same level, prefer disablement.
If `NO_COLOR` and `FORCE_COLOR` conflict, disable colour unless an explicit higher-priority choice overrides it.
Document any different policy.

Use red for errors, dim for secondary text, bold for headings, and cyan/blue for paths.
Pair colour with words or symbols.

### Unicode and emoji

Symbols such as ✅, ❌, and ⚠ can clarify state, as in yubikey-agent and starship.
Check locale and `TERM`, and provide `[ok]`, `[!]`, or `[X]` for unsupported or piped output.
Pair emoji with words.
Modern Windows Terminal and macOS/Linux terminals support emoji better than older terminals.

### Paging

Use less or `$PAGER` only when stdout is a TTY.
Honour tool-specific overrides such as `$BAT_PAGER` and `$GIT_PAGER`.
`bat`, `git`, and `gh` use this pattern.

| Flag in `LESS=FIRX` or `less -FIRX` | Effect |
| --- | --- |
| `F` | Exit if content fits one screen |
| `I` | Case-insensitive search |
| `R` | Pass ANSI colour sequences |
| `X` | Preserve the display in scrollback on exit |

## Exit codes

| Code | Meaning |
| --- | --- |
| 0 | Success |
| 1 | General failure |
| 2 | Common parse/usage error, not universal |
| 126 | Command found but not executable |
| 127 | Command not found |
| 128 + N | Signal N, including 130 SIGINT, 143 SIGTERM, 137 SIGKILL |

BSD `sysexits.h` is a legacy, nonportable vocabulary, not a default cross-platform recommendation.

| Code | Constant | Meaning |
| --- | --- | --- |
| 64 | EX_USAGE | Bad usage |
| 65 | EX_DATAERR | Bad input data |
| 66 | EX_NOINPUT | Cannot open input |
| 69 | EX_UNAVAILABLE | Service unavailable |
| 70 | EX_SOFTWARE | Internal error |
| 73 | EX_CANTCREAT | Cannot create output |
| 74 | EX_IOERR | I/O error |
| 75 | EX_TEMPFAIL | Retryable failure |
| 77 | EX_NOPERM | Permission denied |
| 78 | EX_CONFIG | Configuration error |

Document tool-specific meanings in `--help`.
For example, grep/rg use 0 for a match, 1 for no match, and 2 for error.
A smaller documented scheme is often sufficient.

## Error messages

State the attempted operation, failure, cause, fix, and documentation link.

```text
$ myapp dump -o myfile.out
Error: EPERM — invalid permissions on myfile.out
Cannot write to myfile.out; the file is read-only.
Fix with: chmod +w myfile.out
See: https://github.com/jdxcode/myapp#permissions
```

Catch expected errors and replace raw traces with useful messages.
Expose traces only with `--debug` or `DEBUG=1`.
In new messages, put the most actionable information last, preferably the fix command.
Group repeated failures, with a count, a few examples, and an option such as `--show-all-errors`.
Suggest corrections for typos without executing them, as Brew, Heroku, Cargo, Git, and npm do.

## Help and discoverability

### Help entry points

Support `mycli -h`, `mycli --help`, `mycli help`, `mycli sub -h`, and `mycli help sub`.
Without arguments or a sensible default action, show concise help.
Reserve `-h` and `--help` for help.

Concise help needs a sentence, 1-2 examples, main flags/subcommands, and a route to full help.
Study jq's no-argument behaviour.

### Full help

- Use POSIX notation, for example `mycli [-v] [--output FILE] FILE...`.
- Give a 1-3 paragraph description.
- Group flags by purpose, such as General, Output, Filtering, and Auth.
- End with examples ordered from simple to complex.
- Link to documentation, a man page, or `mycli help <topic>`.

Generate man pages from Markdown with ronn or pandoc.
`git help foo` and `npm help foo` demonstrate topic-based man-page access.

### Version information

Support `--version`, `-V`, and a `version` subcommand.
Include semver, short Git SHA, build date, and Go/Node/Python runtime version where relevant.
Make version output easy to copy into bug reports.
For server clients, include the version in `User-Agent`.

### Completions

Generate bash, zsh, fish, and pwsh completions.
Cobra, Click/Typer, clap, commander, yargs, oclif, and picocli support generation.
Complete flags and useful values, such as kubectl resource names, gh repositories/PRs, or Git branches/tags.

## Subcommands

Use a single command for tools like grep, cp, or rg.
For multiple objects, prefer noun-verb commands such as `docker container create`, `gh pr list`, and `gh issue close`.
This keeps actions such as `pr review` and `issue review` distinct.

- Give flags the same meaning across subcommands.
- Do not make `mycli foo` silently mean `mycli run foo`.
- Do not resolve command prefixes automatically. Adding `instance` must not change `ins` from `install`.
- Define explicit aliases instead.
- Avoid confusing pairs such as `update` and `upgrade` unless their distinction is necessary and documented.

## Shell integration

A child cannot directly change its parent shell's working directory or environment.
Use an explicit shell wrapper or generated shell source.

### Directory change on exit

Write the selected directory to a caller-specified file.
Document a wrapper that reads the file and changes the parent shell directory.
Yazi uses `--cwd-file`, and ranger uses `--choosedir`.

```bash
function y() {
    local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
    command yazi "$@" --cwd-file="$tmp"
    IFS= read -r -d '' cwd < "$tmp"
    [ "$cwd" != "$PWD" ] && [ -d "$cwd" ] && builtin cd -- "$cwd"
    command rm -f -- "$tmp"
}
```

### Shell initialisation

Use an `init`/`activate` subcommand that emits shell source for `eval "$(tool init shell)"`.

| Tool | Generated integration |
| --- | --- |
| starship | `precmd` hook to rebuild the prompt |
| zoxide | `z`/`zi` functions and a `chpwd` tracking hook |
| atuin | Ctrl-R binding and history hooks |
| mise | Wrapper and `precmd`/`chpwd` hooks that recompute and export `PATH` |
| fzf | Since v0.48, `--zsh`/`--bash` emit bindings and completions instead of separate install.sh output |

### Shell configuration files

Show the required line and ask the user to add it to the relevant shell file.
Starship, zoxide, and mise use this explicit pattern.
A visible, approved installer step can append it, as atuin's installer does.
Never silently modify shell configuration.

## Configuration and state

### Precedence

Use this order, highest first:

1. CLI flags.
2. Environment variables.
3. Project config, such as `./mytool.toml` or `./.mytoolrc`.
4. User config under `$XDG_CONFIG_HOME/mytool/`.
5. System config under `/etc/mytool/`.
6. Built-in defaults.

### XDG directories

| Variable | Default | Purpose |
| --- | --- | --- |
| `XDG_CONFIG_HOME` | `~/.config` | Configuration |
| `XDG_DATA_HOME` | `~/.local/share` | Persistent data |
| `XDG_STATE_HOME` | `~/.local/state` | Logs, history, state |
| `XDG_CACHE_HOME` | `~/.cache` | Regenerable cache |
| `XDG_RUNTIME_DIR` | No default | Sockets/pipes, mode 0700 |

Prefer `~/.config/mytool/` to a new `~/.mytool/` directory.
On Windows, use `%APPDATA%\mytool` for config and `%LOCALAPPDATA%\mytool` for cache.
For portable developer CLIs on macOS, prefer XDG. GUI-style apps can use `~/Library/Application Support/`.

### Environment variables

Use uppercase prefixes such as `TOOL_FOO_BAR` and single-line values.

| Variable | Meaning |
| --- | --- |
| `NO_COLOR`, `FORCE_COLOR` | Colour policy |
| `DEBUG` | Debug output |
| `EDITOR`, `VISUAL` | Editor |
| `PAGER` | Pager |
| `HTTP_PROXY`, `HTTPS_PROXY`, `NO_PROXY` | Proxies |
| `TMPDIR` | Temporary files |
| `HOME` | Home directory |
| `SHELL` | Login shell |
| `TERM` | Terminal type |
| `LINES`, `COLUMNS` | Terminal size |
| `LANG`, `LC_*` | Locale |

### Secrets

Do not put passwords or tokens in arguments.
`ps`, shell history, `docker inspect`, `systemctl show`, crash dumps, logs, and process accounting can expose them.
Prefer restrictive credential files, stdin, AF_UNIX sockets, OS keychains, or helper protocols.

### First-run authentication

Prefer browser OAuth device flow with tokens in the OS keychain for supported services.
`gh auth login` and `vercel login` demonstrate browser or URL/code approval and token polling.
Support headless input such as `--with-token` from stdin.
Direct credential prompts remain appropriate for long-lived access keys, as in `aws configure`.
AWS also supports device-flow federation with `aws configure sso`.

Before ordinary stdio prompts, check both stdin and stdout with `isatty()`.
For deliberately opened `/dev/tty`, check that channel instead.
Use an environment variable such as `GH_TOKEN` or `VERCEL_TOKEN` to bypass interactive authentication.
Honour `CI=true` as a secondary signal.
Do not claim a universal non-interactive flag.
Django uses `--no-input`, Terraform uses `-input=false`, and Git uses `GIT_TERMINAL_PROMPT=0`. npm and gh have no equivalent flag.

| Language | Credential storage |
| --- | --- |
| Go | `zalando/go-keyring`, used by gh, or `99designs/keyring` with more backends and encrypted-file fallback |
| Rust | `keyring` crate |
| Python | PyPI `keyring`, disabled with `PYTHON_KEYRING_BACKEND=keyring.backends.null.Keyring` |
| Node | Avoid keytar, archived since December 2022. Electron uses `safeStorage`. Plain Node needs an explicit file fallback when no suitable keychain API exists. |

Linux keychains require a Secret Service daemon, such as GNOME Keyring or KWallet, often absent in headless containers.
Make plaintext fallback explicit, as gh does with `--insecure-storage`.
Set file permissions to 0600 at creation. Do not rely on umask.
The upstream example is CVE-2026-13769 in AWS CLI.
`codeartifact login`, `iam create-virtual-mfa-device`, and `deploy register` wrote files as 0644 under the default umask.

## Performance and signals

### Startup

| Time | User effect |
| --- | --- |
| <100ms | Immediate response, required for prompt tools such as starship |
| 100-500ms | Fast |
| 500ms-2s | Noticeable delay |
| 2s+ | Discourages repeated use |

Lazy-load subcommand modules, cache parsed config, and keep update checks off the main startup path.
For shell-prompt latency, compiled Go/Rust usually suits the requirement better than Python/Node.

### Streaming

Process and emit lines incrementally, as grep, jq, and rg do.
Flush stdout on newlines for immediate downstream use.

### Signals

| Signal | Contract |
| --- | --- |
| SIGINT, exit 130 | Acknowledge immediately, bound cleanup, exit. A second Ctrl-C forces exit. |
| SIGTERM, exit 143 | Clean shutdown |
| SIGPIPE | Exit silently with 0 or 141 when a consumer such as head closes early. No trace. |
| SIGHUP | Daemons reload configuration, one-shot tools exit. |

| Language | Broken-pipe handling |
| --- | --- |
| Python | `signal.signal(signal.SIGPIPE, signal.SIG_DFL)` |
| Rust | Handle `ErrorKind::BrokenPipe` |
| Go | Ignore `EPIPE` on stdout |
| Node | Handle `EPIPE` on `process.stdout` |

### Atomicity and idempotency

Write a temporary file, then use `rename(2)` for atomic replacement on supporting filesystems.
Provide `--dry-run` for destructive work, as in rsync, terraform plan, or `git add -n`.
Make repeated runs converge safely.
Use configurable timeouts, exponential backoff, and retries for temporary failures such as `EX_TEMPFAIL` 75.

## Compatibility

Treat the released CLI as an API for scripts.
Prefer additive changes and warn for at least one release cycle before removal.
Human output can evolve. Machine output such as `--json` and `--plain` must remain stable.
Send deprecation notices to stderr with the replacement and removal version.

## Distribution, updates, and telemetry

### Distribution

| Method | Consequence |
| --- | --- |
| Go/Rust binary and Homebrew | No language runtime dependency. Used by ripgrep, starship, zoxide, and atuin. |
| npm platform packages | Use per-platform `optionalDependencies`, as esbuild and `@swc/core` do. |
| Pure npm / pipx | Easier publishing, but needs the runtime. |

GoReleaser replaced `brews` with `homebrew_casks`, with deprecation in v2.10 and hard deprecation in v2.16.
Prefer platform packages such as `@esbuild/darwin-arm64` over postinstall downloads.
Postinstall downloads fail with offline installs, custom registries, or `--ignore-scripts`.

### Update checks

Check asynchronously and cache results, normally for 24 hours as gh and update-notifier do.
Print notices to stderr after normal output.
Skip checks in CI and when stdout is not a TTY.
Provide opt-outs such as `GH_NO_UPDATE_NOTIFIER` or `NO_UPDATE_NOTIFIER`.

Use the package manager that installed the tool for updates.
Do not suggest self-update for a Homebrew-owned installation.
gh disables its checker in precompiled/package-manager binaries.
The upstream example of failure is gemini-cli misidentifying npm installations and recommending an ineffective `brew upgrade`.

### Telemetry

Disclose collection before sending any data, as Homebrew does.
Provide a tool-specific environment opt-out and a command such as `tool telemetry disable`.
Skip telemetry in CI and honour `DO_NOT_TRACK=1` as an additional opt-out.
Check disablement first, without exceptions or a final event that reports the opt-out.
Netlify CLI previously sent such an event, contrary to the user's choice.

`DO_NOT_TRACK=1` has limited adoption. Its author withdrew support in 2024.
Netdata, tilt, and gh since 2026 honour it.
Homebrew, Gatsby, Syncthing, and .NET rejected adoption. Next.js, Vercel CLI, Prisma, and Netlify CLI also ignore it.
Existing alternatives include `HOMEBREW_NO_ANALYTICS`, `GATSBY_TELEMETRY_DISABLED`, and `DOTNET_CLI_TELEMETRY_OPTOUT`.

## Naming

Use short lowercase names that are easy to type and distinct from existing commands.
Use hyphens for multiple words, for example `gh-actions-helper`, not `gh_actions_helper`.
Prefer `curl`-style casing over `DownloadURL`.

## Examples to study

| Tool | Useful design |
| --- | --- |
| gh | Noun-verb commands, `--json field1,field2`, `--jq '...'`, `--template '...'`, keychains, paging |
| rg | gitignore/binary defaults, recursion, smart-case, NDJSON, `RIPGREP_CONFIG_PATH`, exit 0/1/2, linear-time regex |
| fd | Regex, colour, gitignore, `-x cmd {}` |
| bat | TTY colour/paging, plain pipes, `--plain`/`-p`, `$BAT_PAGER`/`$PAGER` |
| jq | Fast startup, `-r`, `-c`, `-s`, help without arguments |
| httpie / xh | Readable HTTP on TTY, raw pipes. xh reduces startup delay. |
| kubectl | Output projections, API completions, `--dry-run=client\|server` |
| docker | Nested commands, parallel layer progress, aliases such as `docker ps` and `docker container ls` |
| delta | Side-by-side diff through Git `core.pager` and stdin |
| eza | ls-like output, Git state, `--tree` |
| starship | Cross-shell prompt, sub-100ms requirement, one TOML config |

## Final checklist

- Return 0 for success and documented non-zero codes for failure.
- Send results to stdout and diagnostics to stderr.
- Support `-`, `--`, SIGPIPE cleanup, and two-stage Ctrl-C handling.
- Supply concise/full help, examples, completions, and version details.
- Use consistent long/short flags and explicit machine formats.
- Keep tables border-free, headers optional, and default logs free of level prefixes.
- Apply colour precedence, Unicode fallback, and non-TTY animation suppression.
- Explain errors and fixes without default traces or automatic typo execution.
- Require interactive channels for prompts and explicit non-interactive contracts for scripts.
- Confirm destructive work and keep secrets out of arguments.
- Apply XDG paths, prefixed environment variables, and documented precedence.
- Target cold startup below 500ms, or below 100ms for prompt-level tools.
- Stream output and use atomic, repeatable operations with dry-run support.
- Keep machine output stable and provide deprecation notice before removal.

If the product needs a full-screen session, return to `SKILL.md` and select an ecosystem reference.
A shared core can support both scripted CLI work and interactive TUI exploration, as gh, helix, atuin, and Posting demonstrate.
