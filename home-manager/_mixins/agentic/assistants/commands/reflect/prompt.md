## Reflect

Look back over this session and suggest changes to the agentic command and skill tree, and to this project's `AGENTS.md`, so a repeated manual request becomes a command, a corrected command gets fixed, and a corrected convention gets written down.

Focus: `$ARGUMENTS` (if blank, review the whole session).

### The bar

This is a light-touch review. Hold to it.

- Suggest a change only where the session shows the same request twice or more, or where the user corrected a command's or skill's output, or corrected the same point about this project's conventions more than once.
- One request is not a pattern. A single novel task is not evidence of a missing command.
- At most three change suggestions across every finding type. `AGENTS.md` findings compete with command and skill findings for the same three slots, on the same evidence. Fewer is better. Zero is a normal and correct result: say so plainly rather than padding the list to fill it.
- Every suggestion carries its evidence: what the user asked and how many times, or the command name and what they corrected. A suggestion without evidence cannot be judged, so it does not ship.

### Finding types

| Type          | Trigger                                                               | Recommendation                                                                    |
| ------------- | --------------------------------------------------------------------- | --------------------------------------------------------------------------------- |
| Missing       | A task driven by hand more than once, with no command or skill for it | A new command or skill, or folding it into an existing one. Say which.            |
| Wrong         | A command or skill the user had to correct                            | The specific change that stops the correction recurring. Name the file.           |
| Convention    | A correction about this project, made more than once                  | The change to this repository's `AGENTS.md`. Quote the line to add or fix.        |
| Already there | A task driven by hand that an existing command already does           | A usage note, not a change. Report it separately; it is outside the cap of three. |

### Where a correction belongs

Decide this before writing the suggestion, or the same correction lands in either place at random.

- A correction about **this project**, its paths, the commands to run, its house style, its conventions, belongs in `AGENTS.md`.
- A correction about **how a command behaves anywhere** belongs in the command or the skill.

`AGENTS.md` sits in the repository this session is running in, not in the tree at `~/Zero/nix-config`. Read the repository's own `AGENTS.md` when reflecting. The `write-agents-md` skill covers `CLAUDE.md`, nested files, and precedence; follow it rather than restating the rules here.

Where the repository has no `AGENTS.md`, recommend `create-agents-md`, but only where the session shows repeated corrections about conventions. An absent `AGENTS.md` is not a finding on its own.

### Orient first

The tree lives at `~/Zero/nix-config/home-manager/_mixins/agentic/assistants/`. This session may be running anywhere, so check what exists before judging what is missing.

Keep it cheap. List the directory names under `agents/`, `commands/`, `agents/*/commands/`, and `skills/`. The names are descriptive, so shortlist from them, then read `description.txt` or the `SKILL.md` frontmatter for the few candidates that matter. Do not read `README.md`. Do not read every prompt: the tree holds dozens of commands, and this review does not warrant that cost.

### Act only on what the user picks

Report first. Never edit anything before the user chooses.

For each accepted suggestion, delegate to `rosey`, one sub-agent per suggestion. Rosey owns prompts, skills, commands, and instruction files, and runs `create-command`, `update-command`, `create-skill`, `update-skill`, `update-agents-md`, or `create-agents-md` as the case needs.

The edits land in two different repositories. A command or skill change lands in `~/Zero/nix-config`, which is usually not the repository this session is working in. An `AGENTS.md` change lands in the current repository, which at work may be a file shared with colleagues, so it carries further than a personal command change and needs the same report-first gate as everything else.

Tell Rosey to report the paths it changed and never commit. Name the repository beside every changed path in the final report, so uncommitted work is not found days later in the wrong tree.

### Output

```markdown
## Suggestions

### 1. Missing | Wrong | Convention - <the change in one line>

Evidence: <what the user asked and how many times, or the command and what they corrected>
Change: <the new command or skill, or the file to edit>

## Already there

- `<command>` - <the task driven by hand that it already covers>

## Changed

- `<repository>` - `<path>` - <what changed>
```

With no suggestions, the whole output is the single line `Nothing to suggest.` Keep the `Already there` section only when it has entries. Write the `Changed` section only after the user has picked and Rosey has reported.

### Constraints

- Report before editing. The user chooses what ships.
- Three change suggestions is the hard cap across Missing, Wrong, and Convention together. Zero is correct when the session shows no pattern.
- No evidence, no suggestion.
- British spelling. No hedging language.
