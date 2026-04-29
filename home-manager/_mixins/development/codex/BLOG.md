# Making Codex Behave on NixOS

Right, confession time. I thought wiring **Codex** into my NixOS and Home Manager setup would be the usual declarative victory lap. Add the package, write the config, sprinkle in some MCP servers, enjoy the smug glow of reproducibility.

Then Codex started doing what all useful tools eventually do on NixOS: it found the one assumption I had not modelled.

The result was a surprisingly educational tour through Linux sandboxing, mutable runtime state, Nix daemon sockets, and why symlinks are not always the tidy answer they appear to be.

## The Problem

On a normal Linux distribution, Codex can usually assume its executable path, config path, and runtime state all behave like regular mutable files. On NixOS, those assumptions need checking.

The first problem was the Codex binary itself. Codex enters its Linux sandbox by re-executing `std::env::current_exe()`. That sounds harmless until the executable lives in the Nix store, or worse, behind a wrapper.

Nix store paths are immutable, but they are also generation-bound. Home Manager can switch generations while a long-running tool still expects its old executable path to exist. Nix wrappers add another twist: the thing you run may not be the thing Codex needs to re-exec when it becomes `codex-linux-sandbox`.

The second problem was configuration. Codex writes runtime state back to **`config.toml`**, including trust decisions. A Home Manager symlink into the read-only Nix store looks elegant, then quietly ruins your afternoon when Codex cannot persist what it learned.

The third problem was Linux sandbox networking. I wanted Codex to edit freely inside my workspaces and use my chosen MCP servers without nagging me. I also wanted `just eval` to work, because this is NixOS and pretending evaluation is optional is how you summon pain.

## The Wrong Turn

Codex has newer split permission profiles, and they look like exactly the right tool:

```toml
default_permissions = "workspace"

[permissions.workspace.filesystem]
# custom read/write policy here
```

That looked promising. I could deny secrets, allow workspaces, and describe the filesystem properly.

Then Nix broke.

Without a network section in the split profile, Codex installed restricted network seccomp rules. Nix could create a Unix socket, but could not connect to the daemon:

```text
cannot connect to socket at '/nix/var/nix/daemon-socket/socket': Operation not permitted
```

So I tried adding profile network permissions. That fixed one thing and broke another. Codex entered managed proxy mode, and on Linux that mode blocks new **`AF_UNIX`** and **`socketpair`** creation inside commands. Nix, Determinate Nix, and plenty of Tokio-based tools rely on local Unix sockets. That was not a workable trade.

At this point the solution was clear, in the annoying way solutions often are after you have eliminated the clever options.

Use the legacy workspace sandbox.

## The Sandbox That Works

The working Codex sandbox config is deliberately plain:

```toml
sandbox_mode = "workspace-write"

[sandbox_workspace_write]
network_access = true
```

That gives Codex write access to the configured workspace roots and leaves normal Unix socket behaviour alone. For Nix, that matters more than fancy filesystem policy.

I also set:

```toml
[shell_environment_policy.set]
NIX_REMOTE = "daemon"
```

That tells Nix to use the daemon store rather than trying to write directly to **`/nix/store`**. With Determinate Nix, this still uses the normal local daemon store protocol. The proof is simple:

```bash
nix store ping
```

On my system that reports the daemon store, Determinate Nix `2.33.3`, and trusted access.

One more Nix wrinkle remained. Evaluation writes flake fetcher locks under:

```text
~/.cache/nix/fetcher-locks
```

If that path is read-only inside the Codex sandbox, `just eval` fails before the daemon can help. So **`~/.cache/nix`** is now an explicit writable root, and activation creates the lock directory.

## The Binary Fix

I stopped running Codex directly from the Nix store. Instead, Home Manager copies the real binary to stable user-owned paths during activation:

```text
~/.local/share/codex/bin/codex
~/.codex/bin/codex
${XDG_CONFIG_HOME}/codex/bin/codex
```

The installed `codex` command is now a tiny launcher that execs the first available copy.

The important bit is that the primary copy lives outside **`CODEX_HOME`**. Codex protects `.codex` paths inside the Linux sandbox, so putting the main executable there is asking for trouble with a polite hat on.

I also clear `postFixup` on the package override so the binary is not wrapped. Codex's sandbox re-exec path wants the actual executable, not a shell script with good intentions.

## The Config Fix

Codex config is now a real mutable file, not a Nix store symlink.

During activation I generate the desired TOML in the store, then merge it into:

```text
~/.codex/config.toml
${XDG_CONFIG_HOME}/codex/config.toml
```

The merge keeps runtime state where that makes sense:

- Existing project trust entries survive.
- Unknown runtime keys survive.
- MCP servers are replaced from Nix, so removed servers do not linger.
- Stale `default_permissions` and `permissions` keys are deleted.

That last point matters. Once I removed split permission profiles, old copies in `config.toml` kept breaking new sessions until the merge script learned to remove them.

## Agents, Skills, and Symlinks

Another NixOS classic: symlinks were too neat.

Codex's Linux role discovery skips symlinked agent role files. So `~/.codex/agents/*.toml` must be real files. The same practical rule applies to generated skills.

The `traya` role gets special treatment. It is generated by a small TOML writer during activation, not by hand-rolled string interpolation in Nix. That keeps long multiline developer instructions, quotes, and secret-provided bond text from producing malformed TOML.

For skills, every generated skill is explicitly enabled in `config.toml`. Codex does not need to prompt for instruction-only skills, so root sessions and spawned agents can use them without interrupting the flow.

## MCP Without Startup Noise

I only wire the MCP servers I actually want:

```text
cloudflare
context7
exa
nixos
svelte
```

I removed `jina` because it needs `JINA_API_KEY`, and I do not want Codex warning about a server I did not mean to start. Declarative config is lovely, but declarative noise is still noise.

## The Result

The final smoke test is pleasingly boring:

```bash
nix store ping
just eval
```

Both pass inside Codex.

The setup now gives me the behaviour I wanted from the start:

- Codex starts without malformed agent warnings.
- MCP servers are the ones I explicitly chose.
- Local workspace edits do not ask for approval.
- Nix evaluation works inside the sandbox.
- Runtime trust decisions survive Home Manager switches.
- Dangerous command prefixes still get blocked by generated rules.

The lesson is not "NixOS makes Codex hard". The lesson is sharper than that: tools with runtime state need somewhere real to stand. Codex needs a stable executable path, a mutable config file, normal local Unix sockets, and writable Nix cache locks.

Once those are declared, Codex on NixOS is rather splendid.
