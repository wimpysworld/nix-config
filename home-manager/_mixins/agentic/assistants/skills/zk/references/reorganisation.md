# Reorganisation

Use this procedure for filename changes, moves, splits, merges, and substantial notebook restructuring.

## Record the starting state

1. Identify the requested scope and the affected notes, incoming links, outgoing links, attachments, and fragments.
2. Record existing broken destinations separately from changes that the task will introduce.
3. Build an explicit old-path-to-new-path map before edits. Include attachment paths and fragment changes where needed.
4. For splits, map each source section to its destination. For merges, record each source and the chosen destination.
5. Check every destination for collisions, including case differences and existing files. Never overwrite a collision.
6. Check whether Weave relies on the affected paths or flat layout. State any concrete conflict before the dependent change.

Keep IDs and the flat layout where they meet the request. Do not substitute tags for an explicitly requested physical move.
Do not require another approval for reversible work that the user already authorised.

## Apply the map

- Create new split destinations through `zk` so configured templates and ID generation remain in control.
- Preserve all source information, qualifications, citations, code, and relevant metadata in the mapped destinations.
- Keep conflicting claims distinct during merges. Do not resolve disagreements through wording changes.
- Preserve each source's provenance and creation information when one destination cannot hold multiple original metadata values.
- Retain source notes after splits and merges unless the user explicitly authorises their removal.
- If source notes become navigation notes, preserve their original information in verified destinations before replacing their bodies.
- Rewrite incoming references to mapped targets. Preserve link labels unless their meaning also needs a change.
- When a note moves, recalculate its outgoing relative note links and attachment paths from the new location.
- When an attachment moves, repair references from every affected note. Preserve the attachment bytes.
- Handle Markdown inline links, reference definitions, images, encoded paths, and fragments in the affected files.
- Leave external URLs, quoted examples, and code blocks unchanged unless the request explicitly covers them.
- Use destination-aware edits. Do not replace IDs as plain text across the notebook.

For a split, send each incoming link to the relevant destination or a retained source navigation note.
Do not send every link to one new note when the original links refer to different source sections.
For a merge, preserve or map heading fragments so existing deep links still reach the intended content.

## Metadata

Preserve the creation `date`, tags, and unknown fields of retained notes.
Let templates supply new-note metadata, then carry source provenance without inventing creation dates.
Set `modified` when bodies or titles change, including source notes changed into navigation notes.
Do not change frontmatter `modified` solely for path or link-target repairs.
Do not restore old filesystem timestamps after substantive edits.

## Validate the result

1. Check that every mapped destination exists and that no destination overwrote unrelated data.
2. Compare source information against destinations. Account for every source section and attachment.
3. Check direct destinations from the edited files and all affected incoming references.
4. Resolve relative paths from the containing note. Decode encoded paths and account for extensionless note links.
5. Check affected fragments against their destination headings using the notebook consumer's rules.
6. Force reindexing and inspect stderr. Query both incoming and outgoing links for the mapped notes.
7. Compare broken links against the starting state. Fix new defects caused by the edits.
8. Report the path map, retained source notes, existing defects, and any checks that remain incomplete.

Do not treat a clean backlink query as proof that attachments or unindexed links work.
Do not delete retained source notes as automatic cleanup.
