Input: `$ARGUMENTS` accepts multiple Linear keys/URLs, GitHub issue/PR URLs, `owner/repo#123` references, local file paths, and source URLs.
Treat any accompanying user text as additional input. When input is blank, use clearly identified conversation references.
If no references are clear, ask for them.

Run this command in the current context. Do not launch a worker or a Task for any step; the purpose is to prime current context.

- Read the supplied sources first.
- Deduplicate references to the same artefact.
- Read directly linked material only when necessary to understand the supplied work.
- Read comments selectively when they supersede or clarify the opening post.
- Disclose unread, incomplete, or inaccessible material rather than extending the scope.

Do not conduct broad searches, compare solutions, investigate gaps, or traverse links recursively.
Do not run `research-task` or `deep-research` workflows.
Do not introduce the team or survey the repository.

**Return:** Target 200-300 words, with source citations beside material findings.

| Section | Content |
| ------- | ------- |
| Goal and scope | Intended outcome and boundaries |
| Material constraints | Requirements and limits that affect the work |
| Prior decisions | Recorded choices and their stated reasons |
| Unresolved questions | Questions or conflicts present in the evidence, without investigation |
| Coverage | Sources read and unread, incomplete, or inaccessible material |

Let me know when you are ready to collaborate.