# Workspace skills

The source is [googleworkspace/cli](https://github.com/googleworkspace/cli/tree/a3768d0e82ad83cca2da97724e46bea4ff0e6dbd/skills), revision `a3768d0e82ad83cca2da97724e46bea4ff0e6dbd`, for `gws` 0.22.5.
Each imported directory includes the upstream Apache-2.0 `LICENSE`. Its `header.toml` records the revision and preserves upstream metadata.

## Selection

The 20 imported names are:

| Service | Skills |
| --- | --- |
| Shared | `gws-shared` |
| Gmail | `gws-gmail`, `gws-gmail-forward`, `gws-gmail-read`, `gws-gmail-reply`, `gws-gmail-reply-all`, `gws-gmail-send`, `gws-gmail-triage`, `gws-gmail-watch` |
| Calendar | `gws-calendar`, `gws-calendar-agenda`, `gws-calendar-insert` |
| Drive | `gws-drive`, `gws-drive-upload` |
| Docs | `gws-docs`, `gws-docs-write` |
| Sheets | `gws-sheets`, `gws-sheets-append`, `gws-sheets-read` |
| Slides | `gws-slides` |

No personas, recipes, or workflow skills are included. Relative skill links retain their upstream names and resolve within this set.
Each skill requires `gws`. The Gmail examples also use `jq`, which the gcloud module supplies.

`compose.nix` excludes `gws-*` by default. The assistant and Codex modules enable the set only for `developer` users on `cg` hosts.
The filter applies before client composition, Pi invocation routes, and the Codex enable list. Other skills keep their existing behaviour.

The shared skill replaces install guidance with Nix ownership and adds local authentication boundaries.
It uses `GOOGLE_WORKSPACE_CLI_CREDENTIALS_FILE` rather than the upstream shared skill's `GOOGLE_APPLICATION_CREDENTIALS` example.
Missing dependencies stop execution rather than trigger `gws generate-skills`.
The Gmail watch skill requires explicit approval for Pub/Sub setup, API enablement, and cleanup.
Authentication, API enablement, and Pub/Sub setup remain explicit user actions. See [authentication steps](../../development/gcloud/README.md).

## Refresh

1. Select an explicit upstream commit compatible with the locked `gws` package.
2. Fetch its archive into a temporary directory. Read its README, authentication source, skill index, and licence.
3. Copy only the selected skill directories. Preserve sibling files and subdirectories. Never replace the whole local `skills` directory.
4. Move YAML frontmatter into `[common]` in `header.toml`. Preserve names, descriptions, and dependency metadata.
5. Keep `SKILL.md` body-only. Add the upstream URL, revision, and `Apache-2.0` licence metadata.
6. Copy the upstream `LICENSE` into each imported directory so client output retains the licence.
7. Reapply the documented local authentication and no-install changes. Review upstream changes before you keep or change those edits.
8. Convert CRLF to LF. Remove trailing whitespace, but convert Markdown hard breaks to backslashes before removal.
9. Check every relative skill link. Add newly required dependencies only after scope approval.
10. Update the selection, revision, and tests together.

Run the focused tests from the repository root:

```bash
python3 -m unittest discover -s home-manager/_mixins/agentic/assistants/tests -p 'test_gws.py'
```

The tests check all tag combinations, four client headers, Pi routes, Codex selection, package dependencies, licences, and relative skill dependencies.
Trigger checks: an unread Gmail summary loads `gws-gmail-triage`. An unrelated local Git task does not load Workspace skills.
A request to configure Gmail watch stops for approval before Pub/Sub changes.
Inspect the generated client directories before you apply the configuration. Use a complete path source when new files remain untracked.
