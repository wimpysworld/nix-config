# ai-usagebar

[ai-usagebar](https://github.com/akitaonrails/ai-usagebar) is a Waybar widget that shows AI plan usage. The package builds it from source, without the tray binary. The shared Waybar component (`home-manager/_mixins/desktop/compositor/components/waybar/`) adds it as `custom/ai-usage` on Linux workstations, before the volume module.

## What each host shows

| Hosts | Claude (`anthropic`) | Codex (`openai`) | OpenCode Go (`opencode-go`) | Default vendor |
| --- | --- | --- | --- | --- |
| `cg` tag | Subscription usage | Subscription usage | Off | Claude |
| No `cg` tag | Off | Subscription usage | Usage from `OPENCODE_ZEN_API_KEY` | Codex |

The module shows only the `󰚩` glyph (Nerd Font `nf-md-robot`, U+F06A9). Left-click the module to show the usage percentage and the time to the next reset. Left-click again to show only the glyph. The tooltip uses `FiraCode Nerd Font Mono`, the font of the Waybar bar, so that its box drawing lines up. Other tooltips keep their font. Scroll on the module to cycle through the enabled vendors. All other vendors, the Anthropic Admin key (`anthropic_api`), and OpenAI admin access are off. Home Manager writes the settings to `~/.config/ai-usagebar/config.toml`. That file is read-only, so the TUI cannot save its Settings.

Hosts without the `cg` tag use an Anthropic API key, which the widget cannot show. Their switch also deletes the Claude login, so Claude stays off there.

The `waybar-ai-usage` wrapper reads the sops-nix secret into `OPENCODE_GO_API_KEY` and then runs the widget. It uses `jq` to wrap the widget's Pango tooltip in a span with the monospace font. When the secret file is missing or empty, OpenCode Go shows no key error until the next refresh. The wrapper puts `notify-send` on `PATH`, so the upstream quota notifications (97 % by default) work.

## Accepted risk: forced logout

When a Claude or Codex access token is within 5 minutes of expiry, the widget refreshes it. It then writes the new token to `~/.claude/.credentials.json` or `~/.codex/auth.json`. Claude Code and Codex do not share the widget's lock. A running `claude` or `codex` process can then use a spent refresh token and ask you to sign in again. This configuration accepts that risk and keeps the upstream behaviour.

Do not symlink either credential file to a managed file. The widget replaces a symlink with a regular file when it writes a token.

If unexpected sign-in prompts occur, set `anthropic.enabled` or `openai.enabled` to `false` in the Waybar component.

## Updates

The freshener job opens update pull requests with automerge off. Review the upstream diff before you merge an update.
