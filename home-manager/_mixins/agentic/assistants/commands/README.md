# Assistant commands

Generated from validated metadata. Run `just update-assistant-catalogue` to update this file.

An associated agent does not imply worker execution. Caller-context takes precedence over dispatch controls. Claude, Codex, and Pi commands have no model pins. OpenCode command model routes remain supported, including caller-context commands. The tables describe generated entry behaviour, not observed runtime execution.

Claude Code, OpenCode, and Pi use `/name`. Codex uses manual-only `$name` skills. OpenCode `/init` separately reads the create-agents-md body with its Rosey binding.

| Command | Description | Associated agent | Visibility | Claude Code | OpenCode | Codex | Pi |
| --- | --- | --- | --- | --- | --- | --- | --- |
| [ack](./ack/command.toml) | Acknowledge feedback 👂 | Unset | public | Caller context | Caller context, subtask: false | Caller context | Caller context |
| [add-agentic-repo-capability](./add-agentic-repo-capability/command.toml) | Add Agentic Repo Capability 🧰 | donatello | public | Task worker: donatello | Native subtask: donatello | spawn_agent: donatello | Agent worker: donatello |
| [add-enricher-capability](./add-enricher-capability/command.toml) | Add manifest-gen enricher capability 🧬 | donatello | secret | Caller context | Caller context, subtask: false | Caller context | Caller context |
| [address-code-review](./address-code-review/command.toml) | Address Code Review 👀 | donatello | public | Caller context | Caller context, subtask: false | Caller context | Caller context |
| [ahem](./ahem/command.toml) | Politely re-issue the Communication Rules 📜 | Unset | public | Caller context | Caller context, subtask: false | Caller context | Caller context |
| [align-documentation](./align-documentation/command.toml) | Align Documentation 📚 | velma | public | Task worker: velma | Native subtask: velma | spawn_agent: velma | Agent worker: velma |
| [ask](./ask/command.toml) | Answer a question 💬 | Unset | public | Caller context | Caller context, subtask: false | Caller context | Caller context |
| [audit-code-security](./audit-code-security/command.toml) | Audit Code Security 🔍 | dibble | public | Caller context | Caller context, subtask: false | Caller context | Caller context |
| [audit-infra-security](./audit-infra-security/command.toml) | Audit Infrastructure Security 🛡️ | batfink | public | Caller context | Caller context, subtask: false | Caller context | Caller context |
| [babysit-pr](./babysit-pr/command.toml) | Babysit a PR to the finish line 🍼 | donatello | public | Caller context | Caller context, subtask: false | Caller context | Caller context |
| [call](./call/command.toml) | Make the call 🎯 | Unset | public | Caller context | Caller context, subtask: false | Caller context | Caller context |
| [clarify-plan](./clarify-plan/command.toml) | Clarify Plan 💎 | Unset | public | Caller context | Caller context, subtask: false | Caller context | Caller context |
| [collaborate](./collaborate/command.toml) | Read supplied sources and prepare to collaborate 🤝 | Unset | public | Caller context | Caller context, subtask: false | Caller context | Caller context |
| [create-agents-md](./create-agents-md/command.toml) | Create AGENTS.md 🤖 | rosey | public | Task worker: rosey | Native subtask: rosey | spawn_agent: rosey | Agent worker: rosey |
| [create-assistant](./create-assistant/command.toml) | Create AI Assistant ✨ | rosey | public | Task worker: rosey | Native subtask: rosey | spawn_agent: rosey | Agent worker: rosey |
| [create-command](./create-command/command.toml) | Create Slash Command 🪄 | rosey | public | Task worker: rosey | Native subtask: rosey | spawn_agent: rosey | Agent worker: rosey |
| [create-plan](./create-plan/command.toml) | Create Plan 💾 | donatello | public | Task worker: donatello | Native subtask: donatello | spawn_agent: donatello | Agent worker: donatello |
| [create-project](./create-project/command.toml) | Create Project 🗂️ | penfold | public | Task worker: penfold | Native subtask: penfold | spawn_agent: penfold | Agent worker: penfold |
| [create-skill](./create-skill/command.toml) | Create Skill 🧩 | rosey | public | Task worker: rosey | Native subtask: rosey | spawn_agent: rosey | Agent worker: rosey |
| [create-task](./create-task/command.toml) | Create Task 📝 | penfold | public | Caller context | Caller context, subtask: false | Caller context | Caller context |
| [draft-blog-post](./draft-blog-post/command.toml) | Draft Blog Post ✍️ | casper | public | Task worker: casper | Native subtask: casper | spawn_agent: casper | Agent worker: casper |
| [draft-code-review](./draft-code-review/command.toml) | Draft Code Review ✍️ | donatello | public | Task worker: donatello | Native subtask: donatello | spawn_agent: donatello | Agent worker: donatello |
| [draft-commit-message](./draft-commit-message/command.toml) | Draft Commit Message ✍️ | garfield | public | Task worker: garfield | Native subtask: garfield, subtask: true | spawn_agent: garfield | Agent worker: garfield |
| [draft-pr-message](./draft-pr-message/command.toml) | Draft PR Message 🐙 | garfield | public | Task worker: garfield | Native subtask: garfield, subtask: true | spawn_agent: garfield | Agent worker: garfield |
| [draft-readme](./draft-readme/command.toml) | Draft README 📄 | velma | public | Task worker: velma | Native subtask: velma | spawn_agent: velma | Agent worker: velma |
| [draft-self-review](./draft-self-review/command.toml) | Draft Self-Review 🪞 | penfold | secret | Task worker: penfold | Native subtask: penfold | spawn_agent: penfold | Agent worker: penfold |
| [draft-video-script](./draft-video-script/command.toml) | Draft Video Script 🎬 | casper | public | Task worker: casper | Native subtask: casper | spawn_agent: casper | Agent worker: casper |
| [finish-pr](./finish-pr/command.toml) | Wrap up a finished PR 🧹 | garfield | public | Caller context | Caller context, subtask: false | Caller context | Caller context |
| [gather-review-data](./gather-review-data/command.toml) | Gather Review Data 📊 | penfold | secret | Caller context | Caller context, subtask: false | Caller context | Caller context |
| [gist](./gist/command.toml) | Rewrite the previous response concisely | Unset | public | Caller context | Caller context, subtask: false | Caller context | Caller context |
| [handover-fork](./handover-fork/command.toml) | Compact handover to a worker 🔀 | rosey | public | Caller context | Caller context, subtask: false | Caller context | Caller context |
| [handover-fresh](./handover-fresh/command.toml) | Handover to a fresh session 📤 | rosey | public | Caller context | Caller context, subtask: false | Caller context | Caller context |
| [implement-plan](./implement-plan/command.toml) | Implement Plan 👨‍💻 | donatello | public | Caller context | Caller context, subtask: false | Caller context | Caller context |
| [implement-task](./implement-task/command.toml) | Implement a tracked task end to end 🛠️ | Unset | public | Caller context | Caller context, subtask: false | Caller context | Caller context |
| [make-commit](./make-commit/command.toml) | Draft and make a commit ✍️ | garfield | public | Task worker: garfield | Native subtask: garfield | spawn_agent: garfield | Agent worker: garfield |
| [make-pr](./make-pr/command.toml) | Draft and open a PR 🐙 | garfield | public | Task worker: garfield | Native subtask: garfield | spawn_agent: garfield | Agent worker: garfield |
| [oi](./oi/command.toml) | Bluntly re-issue the Communication Rules 📜 | Unset | public | Caller context | Caller context, subtask: false | Caller context | Caller context |
| [orientate](./orientate/command.toml) | Digest existing sources for orientation 🧭 | penfold | public | Caller context | Caller context, subtask: false | Caller context | Caller context |
| [post-code-review](./post-code-review/command.toml) | Post Code Review 📮 | donatello | public | Task worker: donatello | Native subtask: donatello | spawn_agent: donatello | Agent worker: donatello |
| [post-comment](./post-comment/command.toml) | Post Comment 📤 | penfold | public | Task worker: penfold | Native subtask: penfold | spawn_agent: penfold | Agent worker: penfold |
| [post-issue](./post-issue/command.toml) | Post Issue 📮 | penfold | public | Caller context | Caller context, subtask: false | Caller context | Caller context |
| [project-code-review](./project-code-review/command.toml) | Project Code Review 🔍 | penry | public | Caller context | Caller context, subtask: false | Caller context | Caller context |
| [project-documentation-review](./project-documentation-review/command.toml) | Project Documentation Review 📋 | velma | public | Caller context | Caller context, subtask: false | Caller context | Caller context |
| [project-peer-review](./project-peer-review/command.toml) | Project Peer Review 👁️ | donatello | public | Caller context | Caller context, subtask: false | Caller context | Caller context |
| [project-performance-review](./project-performance-review/command.toml) | Project Performance Review ⚡ | gonzales | public | Caller context | Caller context, subtask: false | Caller context | Caller context |
| [project-polish-comments](./project-polish-comments/command.toml) | Project Polish Comments ✨ | donatello | public | Caller context | Caller context, subtask: false | Caller context | Caller context |
| [project-smells-review](./project-smells-review/command.toml) | Project Smells Review 🦨 | penry | public | Caller context | Caller context, subtask: false | Caller context | Caller context |
| [project-tests-review](./project-tests-review/command.toml) | Project Tests Review 🧪 | brain | public | Caller context | Caller context, subtask: false | Caller context | Caller context |
| [ready](./ready/command.toml) | Get ready 🌱 | Unset | public | Caller context | Caller context, subtask: false | Caller context | Caller context |
| [reflect](./reflect/command.toml) | Reflect on the session and suggest tooling changes 💭 | Unset | public | Caller context | Caller context, subtask: false | Caller context | Caller context |
| [review-code-again](./review-code-again/command.toml) | Review Code Again 🔁 | donatello | public | Task worker: donatello | Native subtask: donatello | spawn_agent: donatello | Agent worker: donatello |
| [review-code-colleague](./review-code-colleague/command.toml) | Review Colleague Code 🔍 | donatello | public | Task worker: donatello | Native subtask: donatello | spawn_agent: donatello | Agent worker: donatello |
| [review-code-community](./review-code-community/command.toml) | Review Community Code 🛡️ | donatello | public | Task worker: donatello | Native subtask: donatello | spawn_agent: donatello | Agent worker: donatello |
| [review-code-mine](./review-code-mine/command.toml) | Review My Code 🪞 | donatello | public | Task worker: donatello | Native subtask: donatello | spawn_agent: donatello | Agent worker: donatello |
| [review-open-source-attestation](./review-open-source-attestation/command.toml) | Open Source Attestation Review 🧾 | penfold | secret | Task worker: penfold | Native subtask: penfold | spawn_agent: penfold | Agent worker: penfold |
| [review-task](./review-task/command.toml) | Review Task 🔬 | penfold | public | Task worker: penfold | Native subtask: penfold | spawn_agent: penfold | Agent worker: penfold |
| [triage-tasks](./triage-tasks/command.toml) | Triage Tasks 🗂️ | penfold | public | Caller context | Caller context, subtask: false | Caller context | Caller context |
| [update-agents-md](./update-agents-md/command.toml) | Update AGENTS.md 🧠 | rosey | public | Task worker: rosey | Native subtask: rosey | spawn_agent: rosey | Agent worker: rosey |
| [update-assistant](./update-assistant/command.toml) | Update AI Assistant ⚡ | rosey | public | Task worker: rosey | Native subtask: rosey | spawn_agent: rosey | Agent worker: rosey |
| [update-command](./update-command/command.toml) | Update Slash Command ⚡ | rosey | public | Task worker: rosey | Native subtask: rosey | spawn_agent: rosey | Agent worker: rosey |
| [update-skill](./update-skill/command.toml) | Update Skill ⚡ | rosey | public | Task worker: rosey | Native subtask: rosey | spawn_agent: rosey | Agent worker: rosey |
| [update-task](./update-task/command.toml) | Update Task ✏️ | penfold | public | Caller context | Caller context, subtask: false | Caller context | Caller context |
| [weekly-update](./weekly-update/command.toml) | Weekly Update 📣 | penfold | public | Task worker: penfold | Native subtask: penfold | spawn_agent: penfold | Agent worker: penfold |
| [work-order-create](./work-order-create/command.toml) | Create Work Order 📋 | penfold | public | Task worker: penfold | Native subtask: penfold | spawn_agent: penfold | Agent worker: penfold |
| [work-order-next](./work-order-next/command.toml) | Find Next Work 👉 | penfold | public | Task worker: penfold | Native subtask: penfold | spawn_agent: penfold | Agent worker: penfold |
| [work-order-plan](./work-order-plan/command.toml) | Plan Work Order 📐 | penfold | public | Task worker: penfold | Native subtask: penfold | spawn_agent: penfold | Agent worker: penfold |
| [work-order-update](./work-order-update/command.toml) | Update Work Order ✏️ | penfold | public | Task worker: penfold | Native subtask: penfold | spawn_agent: penfold | Agent worker: penfold |
| [wtb](./wtb/command.toml) | Want to Buy 🪿 | Unset | public | Caller context | Caller context, subtask: false | Caller context | Caller context |

## Client metadata differences

Only description overrides and nonempty argument hints are shown. When any client has an argument hint, all clients are listed to show absent hints. Same as common means no description override. Unset means that the argument hint is absent.

| Command | Client | Description override | Argument hint |
| --- | --- | --- | --- |
| [ack](./ack/command.toml) | claude | Same as common | [phase] |
| [ack](./ack/command.toml) | opencode | Same as common | [phase] |
| [ack](./ack/command.toml) | codex | Same as common | Unset |
| [ack](./ack/command.toml) | pi | Same as common | [phase] |
| [add-agentic-repo-capability](./add-agentic-repo-capability/command.toml) | claude | Same as common | [capability] |
| [add-agentic-repo-capability](./add-agentic-repo-capability/command.toml) | opencode | Same as common | [capability] |
| [add-agentic-repo-capability](./add-agentic-repo-capability/command.toml) | codex | Same as common | Unset |
| [add-agentic-repo-capability](./add-agentic-repo-capability/command.toml) | pi | Same as common | [capability] |
| [add-enricher-capability](./add-enricher-capability/command.toml) | claude | Same as common | [capability] |
| [add-enricher-capability](./add-enricher-capability/command.toml) | opencode | Same as common | Unset |
| [add-enricher-capability](./add-enricher-capability/command.toml) | codex | Same as common | Unset |
| [add-enricher-capability](./add-enricher-capability/command.toml) | pi | Same as common | [capability] |
| [address-code-review](./address-code-review/command.toml) | claude | Same as common | [pr\|file\|text] |
| [address-code-review](./address-code-review/command.toml) | opencode | Same as common | Unset |
| [address-code-review](./address-code-review/command.toml) | codex | Same as common | Unset |
| [address-code-review](./address-code-review/command.toml) | pi | Same as common | [pr\|file\|text] |
| [align-documentation](./align-documentation/command.toml) | claude | Same as common | [scope] |
| [align-documentation](./align-documentation/command.toml) | opencode | Same as common | Unset |
| [align-documentation](./align-documentation/command.toml) | codex | Same as common | Unset |
| [align-documentation](./align-documentation/command.toml) | pi | Same as common | [scope] |
| [ask](./ask/command.toml) | claude | Same as common | &lt;question&gt; |
| [ask](./ask/command.toml) | opencode | Same as common | &lt;question&gt; |
| [ask](./ask/command.toml) | codex | Same as common | Unset |
| [ask](./ask/command.toml) | pi | Same as common | &lt;question&gt; |
| [babysit-pr](./babysit-pr/command.toml) | claude | Same as common | [pr-url] |
| [babysit-pr](./babysit-pr/command.toml) | opencode | Same as common | [pr-url] |
| [babysit-pr](./babysit-pr/command.toml) | codex | Same as common | Unset |
| [babysit-pr](./babysit-pr/command.toml) | pi | Same as common | [pr-url] |
| [call](./call/command.toml) | claude | Same as common | [topic] |
| [call](./call/command.toml) | opencode | Same as common | [topic] |
| [call](./call/command.toml) | codex | Same as common | Unset |
| [call](./call/command.toml) | pi | Same as common | [topic] |
| [clarify-plan](./clarify-plan/command.toml) | claude | Same as common | [plan] |
| [clarify-plan](./clarify-plan/command.toml) | opencode | Same as common | [plan] |
| [clarify-plan](./clarify-plan/command.toml) | codex | Same as common | Unset |
| [clarify-plan](./clarify-plan/command.toml) | pi | Same as common | [plan] |
| [collaborate](./collaborate/command.toml) | claude | Same as common | [references...] |
| [collaborate](./collaborate/command.toml) | opencode | Same as common | [references...] |
| [collaborate](./collaborate/command.toml) | codex | Same as common | Unset |
| [collaborate](./collaborate/command.toml) | pi | Same as common | [references...] |
| [create-agents-md](./create-agents-md/command.toml) | claude | Same as common | [file] |
| [create-agents-md](./create-agents-md/command.toml) | opencode | Same as common | [file] |
| [create-agents-md](./create-agents-md/command.toml) | codex | Same as common | Unset |
| [create-agents-md](./create-agents-md/command.toml) | pi | Same as common | [file] |
| [create-assistant](./create-assistant/command.toml) | claude | Same as common | [agent-name] |
| [create-assistant](./create-assistant/command.toml) | opencode | Same as common | [agent-name] |
| [create-assistant](./create-assistant/command.toml) | codex | Same as common | Unset |
| [create-assistant](./create-assistant/command.toml) | pi | Same as common | [agent-name] |
| [create-command](./create-command/command.toml) | claude | Same as common | [command-name] |
| [create-command](./create-command/command.toml) | opencode | Same as common | [command-name] |
| [create-command](./create-command/command.toml) | codex | Same as common | Unset |
| [create-command](./create-command/command.toml) | pi | Same as common | [command-name] |
| [create-plan](./create-plan/command.toml) | claude | Same as common | [task] |
| [create-plan](./create-plan/command.toml) | opencode | Same as common | Unset |
| [create-plan](./create-plan/command.toml) | codex | Same as common | Unset |
| [create-plan](./create-plan/command.toml) | pi | Same as common | [task] |
| [create-project](./create-project/command.toml) | claude | Same as common | &lt;name&gt; [team] |
| [create-project](./create-project/command.toml) | opencode | Same as common | &lt;name&gt; [team] |
| [create-project](./create-project/command.toml) | codex | Same as common | Unset |
| [create-project](./create-project/command.toml) | pi | Same as common | &lt;name&gt; [team] |
| [create-skill](./create-skill/command.toml) | claude | Same as common | [skill-name] |
| [create-skill](./create-skill/command.toml) | opencode | Same as common | [skill-name] |
| [create-skill](./create-skill/command.toml) | codex | Same as common | Unset |
| [create-skill](./create-skill/command.toml) | pi | Same as common | [skill-name] |
| [create-task](./create-task/command.toml) | claude | Same as common | &lt;project\|path&gt; |
| [create-task](./create-task/command.toml) | opencode | Same as common | Unset |
| [create-task](./create-task/command.toml) | codex | Same as common | Unset |
| [create-task](./create-task/command.toml) | pi | Same as common | &lt;project\|path&gt; |
| [draft-blog-post](./draft-blog-post/command.toml) | claude | Same as common | [topic] |
| [draft-blog-post](./draft-blog-post/command.toml) | opencode | Same as common | Unset |
| [draft-blog-post](./draft-blog-post/command.toml) | codex | Same as common | Unset |
| [draft-blog-post](./draft-blog-post/command.toml) | pi | Same as common | [topic] |
| [draft-code-review](./draft-code-review/command.toml) | claude | Same as common | [pr\|branch\|worktree\|commit] |
| [draft-code-review](./draft-code-review/command.toml) | opencode | Same as common | [pr\|branch\|worktree\|commit] |
| [draft-code-review](./draft-code-review/command.toml) | codex | Same as common | Unset |
| [draft-code-review](./draft-code-review/command.toml) | pi | Same as common | Unset |
| [draft-self-review](./draft-self-review/command.toml) | claude | Same as common | &lt;cycle&gt; [activity-file] |
| [draft-self-review](./draft-self-review/command.toml) | opencode | Same as common | &lt;cycle&gt; [activity-file] |
| [draft-self-review](./draft-self-review/command.toml) | codex | Same as common | Unset |
| [draft-self-review](./draft-self-review/command.toml) | pi | Same as common | &lt;cycle&gt; [activity-file] |
| [draft-video-script](./draft-video-script/command.toml) | claude | Same as common | [topic] |
| [draft-video-script](./draft-video-script/command.toml) | opencode | Same as common | Unset |
| [draft-video-script](./draft-video-script/command.toml) | codex | Same as common | Unset |
| [draft-video-script](./draft-video-script/command.toml) | pi | Same as common | [topic] |
| [finish-pr](./finish-pr/command.toml) | claude | Same as common | [branch] |
| [finish-pr](./finish-pr/command.toml) | opencode | Same as common | [branch] |
| [finish-pr](./finish-pr/command.toml) | codex | Same as common | Unset |
| [finish-pr](./finish-pr/command.toml) | pi | Same as common | [branch] |
| [gather-review-data](./gather-review-data/command.toml) | claude | Same as common | &lt;start-date&gt; &lt;end-date&gt; |
| [gather-review-data](./gather-review-data/command.toml) | opencode | Same as common | &lt;start-date&gt; &lt;end-date&gt; |
| [gather-review-data](./gather-review-data/command.toml) | codex | Same as common | Unset |
| [gather-review-data](./gather-review-data/command.toml) | pi | Same as common | &lt;start-date&gt; &lt;end-date&gt; |
| [handover-fork](./handover-fork/command.toml) | claude | Same as common | [focus] |
| [handover-fork](./handover-fork/command.toml) | opencode | Same as common | [focus] |
| [handover-fork](./handover-fork/command.toml) | codex | Same as common | Unset |
| [handover-fork](./handover-fork/command.toml) | pi | Same as common | [focus] |
| [handover-fresh](./handover-fresh/command.toml) | claude | Same as common | [focus] |
| [handover-fresh](./handover-fresh/command.toml) | opencode | Same as common | [focus] |
| [handover-fresh](./handover-fresh/command.toml) | codex | Same as common | Unset |
| [handover-fresh](./handover-fresh/command.toml) | pi | Same as common | [focus] |
| [implement-plan](./implement-plan/command.toml) | claude | Same as common | [plan-file] [phase] |
| [implement-plan](./implement-plan/command.toml) | opencode | Same as common | Unset |
| [implement-plan](./implement-plan/command.toml) | codex | Same as common | Unset |
| [implement-plan](./implement-plan/command.toml) | pi | Same as common | [plan-file] [phase] |
| [implement-task](./implement-task/command.toml) | claude | Same as common | [issue-or-path] |
| [implement-task](./implement-task/command.toml) | opencode | Same as common | [issue-or-path] |
| [implement-task](./implement-task/command.toml) | codex | Same as common | Unset |
| [implement-task](./implement-task/command.toml) | pi | Same as common | [issue-or-path] |
| [make-commit](./make-commit/command.toml) | claude | Same as common | [context] |
| [make-commit](./make-commit/command.toml) | opencode | Same as common | [context] |
| [make-commit](./make-commit/command.toml) | codex | Same as common | Unset |
| [make-commit](./make-commit/command.toml) | pi | Same as common | [context] |
| [make-pr](./make-pr/command.toml) | claude | Same as common | [context] |
| [make-pr](./make-pr/command.toml) | opencode | Same as common | [context] |
| [make-pr](./make-pr/command.toml) | codex | Same as common | Unset |
| [make-pr](./make-pr/command.toml) | pi | Same as common | [context] |
| [orientate](./orientate/command.toml) | claude | Same as common | [sources ...] |
| [orientate](./orientate/command.toml) | opencode | Same as common | [sources ...] |
| [orientate](./orientate/command.toml) | codex | Same as common | Unset |
| [orientate](./orientate/command.toml) | pi | Same as common | [sources ...] |
| [post-code-review](./post-code-review/command.toml) | claude | Same as common | [approve\|comment] [text] |
| [post-code-review](./post-code-review/command.toml) | opencode | Same as common | [approve\|comment] [text] |
| [post-code-review](./post-code-review/command.toml) | codex | Same as common | Unset |
| [post-code-review](./post-code-review/command.toml) | pi | Same as common | [approve\|comment] [text] |
| [post-comment](./post-comment/command.toml) | claude | Same as common | [target] |
| [post-comment](./post-comment/command.toml) | opencode | Same as common | [target] |
| [post-comment](./post-comment/command.toml) | codex | Same as common | Unset |
| [post-comment](./post-comment/command.toml) | pi | Same as common | [target] |
| [post-issue](./post-issue/command.toml) | claude | Same as common | &lt;repo&gt; |
| [post-issue](./post-issue/command.toml) | opencode | Same as common | &lt;repo&gt; |
| [post-issue](./post-issue/command.toml) | codex | Same as common | Unset |
| [post-issue](./post-issue/command.toml) | pi | Same as common | &lt;repo&gt; |
| [project-polish-comments](./project-polish-comments/command.toml) | claude | Same as common | [paths] [scope] |
| [project-polish-comments](./project-polish-comments/command.toml) | opencode | Same as common | Unset |
| [project-polish-comments](./project-polish-comments/command.toml) | codex | Same as common | Unset |
| [project-polish-comments](./project-polish-comments/command.toml) | pi | Same as common | [paths] [scope] |
| [ready](./ready/command.toml) | claude | Same as common | [topic] |
| [ready](./ready/command.toml) | opencode | Same as common | [topic] |
| [ready](./ready/command.toml) | codex | Same as common | Unset |
| [ready](./ready/command.toml) | pi | Same as common | [topic] |
| [reflect](./reflect/command.toml) | claude | Same as common | [focus] |
| [reflect](./reflect/command.toml) | opencode | Same as common | [focus] |
| [reflect](./reflect/command.toml) | codex | Same as common | Unset |
| [reflect](./reflect/command.toml) | pi | Same as common | [focus] |
| [review-code-again](./review-code-again/command.toml) | claude | Same as common | [target\|report] |
| [review-code-again](./review-code-again/command.toml) | opencode | Same as common | [target\|report] |
| [review-code-again](./review-code-again/command.toml) | codex | Same as common | Unset |
| [review-code-again](./review-code-again/command.toml) | pi | Same as common | [target\|report] |
| [review-code-colleague](./review-code-colleague/command.toml) | claude | Same as common | [pr\|branch\|worktree\|commit] |
| [review-code-colleague](./review-code-colleague/command.toml) | opencode | Same as common | [pr\|branch\|worktree\|commit] |
| [review-code-colleague](./review-code-colleague/command.toml) | codex | Same as common | Unset |
| [review-code-colleague](./review-code-colleague/command.toml) | pi | Same as common | [pr\|branch\|worktree\|commit] |
| [review-code-community](./review-code-community/command.toml) | claude | Same as common | [pr\|branch\|worktree\|commit] |
| [review-code-community](./review-code-community/command.toml) | opencode | Same as common | [pr\|branch\|worktree\|commit] |
| [review-code-community](./review-code-community/command.toml) | codex | Same as common | Unset |
| [review-code-community](./review-code-community/command.toml) | pi | Same as common | [pr\|branch\|worktree\|commit] |
| [review-code-mine](./review-code-mine/command.toml) | claude | Same as common | [pr\|branch\|worktree\|commit] |
| [review-code-mine](./review-code-mine/command.toml) | opencode | Same as common | [pr\|branch\|worktree\|commit] |
| [review-code-mine](./review-code-mine/command.toml) | codex | Same as common | Unset |
| [review-code-mine](./review-code-mine/command.toml) | pi | Same as common | [pr\|branch\|worktree\|commit] |
| [review-open-source-attestation](./review-open-source-attestation/command.toml) | claude | Same as common | [pr\|branch\|worktree] |
| [review-open-source-attestation](./review-open-source-attestation/command.toml) | opencode | Same as common | [pr\|branch\|worktree] |
| [review-open-source-attestation](./review-open-source-attestation/command.toml) | codex | Same as common | Unset |
| [review-open-source-attestation](./review-open-source-attestation/command.toml) | pi | Same as common | [pr\|branch\|worktree] |
| [review-task](./review-task/command.toml) | claude | Same as common | [issue-or-file] |
| [review-task](./review-task/command.toml) | opencode | Same as common | Unset |
| [review-task](./review-task/command.toml) | codex | Same as common | Unset |
| [review-task](./review-task/command.toml) | pi | Same as common | [issue-or-file] |
| [triage-tasks](./triage-tasks/command.toml) | claude | Same as common | [issue-id ...] |
| [triage-tasks](./triage-tasks/command.toml) | opencode | Same as common | [issue-id ...] |
| [triage-tasks](./triage-tasks/command.toml) | codex | Same as common | Unset |
| [triage-tasks](./triage-tasks/command.toml) | pi | Same as common | [issue-id ...] |
| [update-agents-md](./update-agents-md/command.toml) | claude | Same as common | [file] |
| [update-agents-md](./update-agents-md/command.toml) | opencode | Same as common | [file] |
| [update-agents-md](./update-agents-md/command.toml) | codex | Same as common | Unset |
| [update-agents-md](./update-agents-md/command.toml) | pi | Same as common | [file] |
| [update-assistant](./update-assistant/command.toml) | claude | Same as common | [agent-prompt] |
| [update-assistant](./update-assistant/command.toml) | opencode | Same as common | [agent-prompt] |
| [update-assistant](./update-assistant/command.toml) | codex | Same as common | Unset |
| [update-assistant](./update-assistant/command.toml) | pi | Same as common | [agent-prompt] |
| [update-command](./update-command/command.toml) | claude | Same as common | [command-path] |
| [update-command](./update-command/command.toml) | opencode | Same as common | [command-path] |
| [update-command](./update-command/command.toml) | codex | Same as common | Unset |
| [update-command](./update-command/command.toml) | pi | Same as common | [command-path] |
| [update-skill](./update-skill/command.toml) | claude | Same as common | [skill-path] |
| [update-skill](./update-skill/command.toml) | opencode | Same as common | [skill-path] |
| [update-skill](./update-skill/command.toml) | codex | Same as common | Unset |
| [update-skill](./update-skill/command.toml) | pi | Same as common | [skill-path] |
| [update-task](./update-task/command.toml) | claude | Same as common | &lt;issue\|path&gt; |
| [update-task](./update-task/command.toml) | opencode | Same as common | Unset |
| [update-task](./update-task/command.toml) | codex | Same as common | Unset |
| [update-task](./update-task/command.toml) | pi | Same as common | &lt;issue\|path&gt; |
| [weekly-update](./weekly-update/command.toml) | claude | Same as common | &lt;slack-channel&gt; |
| [weekly-update](./weekly-update/command.toml) | opencode | Same as common | &lt;slack-channel&gt; |
| [weekly-update](./weekly-update/command.toml) | codex | Same as common | Unset |
| [weekly-update](./weekly-update/command.toml) | pi | Same as common | &lt;slack-channel&gt; |
| [work-order-create](./work-order-create/command.toml) | claude | Same as common | &lt;cycle&gt; [team] |
| [work-order-create](./work-order-create/command.toml) | opencode | Same as common | &lt;cycle&gt; [team] |
| [work-order-create](./work-order-create/command.toml) | codex | Same as common | Unset |
| [work-order-create](./work-order-create/command.toml) | pi | Same as common | &lt;cycle&gt; [team] |
| [work-order-plan](./work-order-plan/command.toml) | claude | Same as common | &lt;projects...&gt; [theme] |
| [work-order-plan](./work-order-plan/command.toml) | opencode | Same as common | &lt;projects...&gt; [theme] |
| [work-order-plan](./work-order-plan/command.toml) | codex | Same as common | Unset |
| [work-order-plan](./work-order-plan/command.toml) | pi | Same as common | &lt;projects...&gt; [theme] |
| [work-order-update](./work-order-update/command.toml) | claude | Same as common | &lt;instructions&gt; |
| [work-order-update](./work-order-update/command.toml) | opencode | Same as common | &lt;instructions&gt; |
| [work-order-update](./work-order-update/command.toml) | codex | Same as common | Unset |
| [work-order-update](./work-order-update/command.toml) | pi | Same as common | &lt;instructions&gt; |
| [wtb](./wtb/command.toml) | claude | Same as common | [pr-url] [#channel] |
| [wtb](./wtb/command.toml) | opencode | Same as common | [pr-url] [#channel] |
| [wtb](./wtb/command.toml) | codex | Same as common | Unset |
| [wtb](./wtb/command.toml) | pi | Same as common | [pr-url] [#channel] |

## Agent model defaults

These are declared agent defaults, not command or caller model assignments. Unset values leave runtime fallback unchanged. Provider routes depend on the active inference provider. OpenCode provider routes apply only to direct-root native task children, not direct slash-command bindings. Explicit supported overrides take precedence. Inline personas do not apply agent model defaults.

| Agent | Client | Inference provider | Model | Effort / thinking |
| --- | --- | --- | --- | --- |
| batfink | claude | Unset | Unset | Unset |
| batfink | opencode | Unset | Unset | Unset |
| batfink | codex | Unset | Unset | Unset |
| batfink | pi | Unset | Unset | Unset |
| brain | claude | Unset | Unset | Unset |
| brain | opencode | Unset | Unset | Unset |
| brain | codex | Unset | Unset | Unset |
| brain | pi | Unset | Unset | Unset |
| casper | claude | Unset | Unset | Unset |
| casper | opencode | Unset | Unset | Unset |
| casper | codex | Unset | Unset | Unset |
| casper | pi | Unset | Unset | Unset |
| dibble | claude | Unset | Unset | Unset |
| dibble | opencode | Unset | Unset | Unset |
| dibble | codex | Unset | Unset | Unset |
| dibble | pi | Unset | Unset | Unset |
| donatello | claude | Unset | Unset | Unset |
| donatello | opencode | Unset | Unset | Unset |
| donatello | codex | Unset | Unset | Unset |
| donatello | pi | Unset | Unset | Unset |
| garfield | claude | Unset | sonnet | Unset |
| garfield | opencode | anthropic | claude-sonnet-5 | Unset |
| garfield | opencode | openai | gpt-5.6-terra | Unset |
| garfield | codex | Unset | gpt-5.6-terra | medium |
| garfield | pi | anthropic | claude-sonnet-5 | Unset |
| garfield | pi | google | gemini-3-flash | Unset |
| garfield | pi | openai-codex | gpt-5.6-terra | medium |
| gonzales | claude | Unset | Unset | Unset |
| gonzales | opencode | Unset | Unset | Unset |
| gonzales | codex | Unset | Unset | Unset |
| gonzales | pi | Unset | Unset | Unset |
| penfold | claude | Unset | Unset | Unset |
| penfold | opencode | Unset | Unset | Unset |
| penfold | codex | Unset | Unset | Unset |
| penfold | pi | Unset | Unset | Unset |
| penry | claude | Unset | Unset | Unset |
| penry | opencode | Unset | Unset | Unset |
| penry | codex | Unset | Unset | Unset |
| penry | pi | Unset | Unset | Unset |
| rosey | claude | Unset | Unset | Unset |
| rosey | opencode | Unset | Unset | Unset |
| rosey | codex | Unset | Unset | Unset |
| rosey | pi | Unset | Unset | Unset |
| velma | claude | Unset | Unset | Unset |
| velma | opencode | Unset | Unset | Unset |
| velma | codex | Unset | Unset | Unset |
| velma | pi | Unset | Unset | Unset |
