# Provenance and limits

Source: [JonoGitty/claude-composer-reaper](https://github.com/JonoGitty/claude-composer-reaper/tree/f8f6d94436ea5fe093658090ea04e09eb36ea597).

Pinned commit: `f8f6d94436ea5fe093658090ea04e09eb36ea597`.
The root MIT `LICENSE` is preserved unchanged.
The portable skill name is `composer-reaper` because skill naming rules reserve `claude`.

## Imported material

The five Lua starters, Swift renderer, and JSFX example retain their upstream contents.
The skill body and eight workflow guides are adapted into concise, provider-neutral instructions.
Starter prompt examples are incorporated into the ReaScript guide rather than copied as a separate prompt catalogue.
Repository installation instructions and the upstream README are not bundled.

The upstream export helper is omitted because it interpolates paths into shell commands and overwrites MP3 output.
The release guide replaces that helper's workflow without those defaults.

## Local adaptation

The live-control guide uses the packaged TwelveTake 1.11.0 API, checked against its installed Python source.
It does not require upstream `dsl_*` tools, premium generation, another server, or a new runtime service.
The existing bridge uses file requests, but its API and lifecycle differ from upstream's `total-reaper-mcp` examples.

Live control remains conditional on the existing studio host and client configuration.
The skill itself is portable across Claude Code, Codex, OpenCode, and Pi through the shared composer.
The macOS Swift renderer is an optional fallback, not a Linux dependency.

## Starter limits

- The colour starter does not route tracks despite its filename.
- The chord starter passes seconds with `false` to `CreateNewMIDIItemInProj`. Its comment about a final `true` is stale.
- The humaniser clamps the start but not the end when a note moves before zero. Review a writable copy before use at boundaries.
- The song starter changes project tempo and adds tracks. It does not load a drum kit.
- The Swift renderer replaces an existing output file. Choose an unused output path before invoking it.
- The Lua starters are examples, not error-safe transactions. Add balanced cleanup when adapting them for production work.

Do not claim that an imported starter passed live REAPER checks unless those checks actually ran.

## Refresh and selection checks

Fetch a chosen upstream revision and inspect its licence before updating the import.
Compare unchanged payloads and licence bytes with that revision.
Reapply the managed-server and output protections, then validate references and generated client files.
Run the repository's catalogue update and check recipes after metadata changes.

Description scenarios:

1. "Make me a synthwave loop in REAPER" loads `composer-reaper` for composition and output selection.
2. "Write a JSFX velocity humaniser" loads `composer-reaper` for MIDI-effect development.
3. "List the tracks through my REAPER MCP" loads `composer-reaper` and starts with read-only discovery.
4. "Measure the LUFS of this podcast WAV" defers to `audio-metrics`, without REAPER composition work.
5. "Build a website for my album" ignores this skill unless a separate audio-production task is requested.
