## Create Pull Request 🐙

Draft a conventional pull request on GitHub for an already-pushed branch.

### Boundary

Garfield does not push, merge, or otherwise mutate refs. `git push` and `gh pr merge` are denied under Fence (see `home-manager/_mixins/agentic/fence/default.nix`). If the branch is not yet pushed, output the `git push -u origin HEAD` command for the user to run, then stop until they confirm.

### Process

1. Gather branch information using **separate** read-only git commands:
   - `git log main..HEAD --oneline` — identify new commits
   - `git diff main..HEAD --stat` — summarise file changes
   - `git status` — verify clean working tree
   - `git rev-parse --abbrev-ref HEAD` — confirm current branch name

   **IMPORTANT**: Run each command individually. Do NOT chain commands with `&&`, `;`, or pipes (`|`). This ensures no manual approval is required.
2. Confirm the branch is already pushed (`git status` reports an upstream, or `git rev-parse --abbrev-ref --symbolic-full-name @{u}` succeeds). If not, output the push command for the user and stop.
3. Apply type selection from agent definition based on commit intent.
4. Create the PR with `gh pr create --title "<type>(<scope>): <description>" --body "<body>"`. Do not merge; `gh pr merge` and `gh pr review --approve` are denied.

### Title Format

`<type>(<scope>): <imperative description>`

Derive type from dominant change intent across commits. Scope from affected component.

### Body Structure

```
## Summary
<one paragraph: why this change exists>

## Changes
- <bullet per logical change>

## Testing
- <validation performed or required>

## Related Issues
Closes #<issue> (if applicable)
```

### Example

<example_input>
Commits on branch:
- abc123 add user avatar upload endpoint
- def456 add avatar validation and resize
- ghi789 update user profile to display avatar
</example_input>

<example_output>
Title: feat(users): add avatar upload and display

Body:
## Summary
Enable users to upload profile avatars with automatic validation and resizing.

## Changes
- Add POST /users/avatar endpoint with file upload handling
- Validate image format and resize to standard dimensions
- Display avatar on user profile page

## Testing
- Tested upload with various image formats
- Verified resize produces consistent output

## Related Issues
Closes #42
</example_output>
