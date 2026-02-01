## Create Pull Request 🐙

Push current branch and create a conventional pull request on GitHub.

### Process

1. Gather branch information using **separate** read-only git commands:
   - `git log main..HEAD --oneline` — identify new commits
   - `git diff main..HEAD --stat` — summarise file changes
   - `git status` — verify clean working tree
   - `git branch --show-current` — confirm current branch name
   
   **IMPORTANT**: Run each command individually. Do NOT chain commands with `&&`, `;`, or pipes (`|`). This ensures no manual approval is required.
2. Push branch with `git push -u origin HEAD`
3. Apply type selection from agent definition based on commit intent
4. Create PR:
   - **Prefer**: GitHub MCP `create_pull_request` tool when available
   - **Fallback**: `gh pr create --title "<type>(<scope>): <description>" --body "<body>"`

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
