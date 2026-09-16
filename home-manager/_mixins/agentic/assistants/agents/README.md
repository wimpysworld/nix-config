# Assistant agents

Generated from validated metadata. Run `just update-assistant-catalogue` to update this file.

These tables describe repository sources and projected client metadata, not installed resources or runtime authority. Client enablement still applies. No metadata override means that this source sets no listed control, not that all tools are allowed.

| Agent | Description | Availability |
| --- | --- | --- |
| [batfink](./batfink/header.toml) | Infrastructure security auditor for cloud, Kubernetes, Docker, CI/CD, network, secrets, and supply-chain config, focused on exploitability and blast radius. | Enabled client |
| [brain](./brain/header.toml) | A pragmatic test engineer who analyses code and coverage to suggest high-impact unit tests that catch real bugs while following existing patterns and maintaining simplicity. | Enabled client |
| [casper](./casper/header.toml) | A technical writer who crafts engaging Linux and open-source content in Martin Wimpress's distinctive British style, blending technical accuracy with personality and humour. | Enabled client |
| [dibble](./dibble/header.toml) | Use for explicit code security audits of application source, dependencies, secrets, and LLM app risks when present. | Enabled client |
| [donatello](./donatello/header.toml) | A methodical implementation engineer who precisely executes code changes from improvement plans while maintaining existing style, verifying tests pass, and seeking clarification when obstacles arise. | Enabled client |
| [garfield](./garfield/header.toml) | A specialised git workflow assistant that enforces best practices for commit messages, pull requests, and code explanations while strictly adhering to Conventional Commits standards. | Enabled client |
| [gonzales](./gonzales/header.toml) | A pragmatic performance specialist who identifies high-impact optimisations in bottlenecks and hotspots while preserving code simplicity and focusing on user-perceivable improvements. | Enabled client |
| [penfold](./penfold/header.toml) | A thoughtful research generalist who explores ideas through dialogue, synthesises findings into context-efficient overviews, and frames problems clearly for downstream specialists. | Enabled client |
| [penry](./penry/header.toml) | A meticulous code reviewer who identifies practical maintainability improvements through simplification, deduplication, and naming clarity while ensuring all changes are small, safe, and preserve exact functionality. | Enabled client |
| [rosey](./rosey/header.toml) | A prompt and skill specialist who crafts, refines, and maintains agent prompts, skills, commands, and instruction files with ruthless token efficiency. | Enabled client |
| [velma](./velma/header.toml) | A documentation architect who creates engaging, well-organised technical documentation by translating code into clear explanations, crafting compelling READMEs, and structuring information for optimal reader comprehension. | Enabled client |

## Projected client controls

Pi defaults come from metadata.project. Descriptions show the client projection, including any override. These controls do not grant authority or list observed runtime tools.

| Agent | Client | Description | Controls |
| --- | --- | --- | --- |
| batfink | claude | Infrastructure security auditor for cloud, Kubernetes, Docker, CI/CD, network, secrets, and supply-chain config, focused on exploitability and blast radius. | {"disallowedTools":["Agent"]} |
| batfink | opencode | Infrastructure security auditor for cloud, Kubernetes, Docker, CI/CD, network, secrets, and supply-chain config, focused on exploitability and blast radius. | {"mode":"subagent","permission":{"question":"allow","task":"deny"}} |
| batfink | codex | Infrastructure security auditor for cloud, Kubernetes, Docker, CI/CD, network, secrets, and supply-chain config, focused on exploitability and blast radius. | No metadata override |
| batfink | pi | Infrastructure security auditor for cloud, Kubernetes, Docker, CI/CD, network, secrets, and supply-chain config, focused on exploitability and blast radius. | {"exclude_extensions":"pi-cc-header","extensions":true,"isolated":false,"prompt_mode":"replace","skills":true} |
| brain | claude | A pragmatic test engineer who analyses code and coverage to suggest high-impact unit tests that catch real bugs while following existing patterns and maintaining simplicity. | {"disallowedTools":["Agent"]} |
| brain | opencode | A pragmatic test engineer who analyses code and coverage to suggest high-impact unit tests that catch real bugs while following existing patterns and maintaining simplicity. | {"mode":"subagent","permission":{"question":"allow","task":"deny"}} |
| brain | codex | A pragmatic test engineer who analyses code and coverage to suggest high-impact unit tests that catch real bugs while following existing patterns and maintaining simplicity. | No metadata override |
| brain | pi | A pragmatic test engineer who analyses code and coverage to suggest high-impact unit tests that catch real bugs while following existing patterns and maintaining simplicity. | {"exclude_extensions":"pi-cc-header","extensions":true,"isolated":false,"prompt_mode":"replace","skills":true} |
| casper | claude | A technical writer who crafts engaging Linux and open-source content in Martin Wimpress's distinctive British style, blending technical accuracy with personality and humour. | {"disallowedTools":["Agent"]} |
| casper | opencode | A technical writer who crafts engaging Linux and open-source content in Martin Wimpress's distinctive British style, blending technical accuracy with personality and humour. | {"mode":"subagent","permission":{"question":"allow","task":"deny"}} |
| casper | codex | A technical writer who crafts engaging Linux and open-source content in Martin Wimpress's distinctive British style, blending technical accuracy with personality and humour. | No metadata override |
| casper | pi | A technical writer who crafts engaging Linux and open-source content in Martin Wimpress's distinctive British style, blending technical accuracy with personality and humour. | {"exclude_extensions":"pi-cc-header","extensions":true,"isolated":false,"prompt_mode":"replace","skills":true} |
| dibble | claude | Use for explicit code security audits of application source, dependencies, secrets, and LLM app risks when present. | {"disallowedTools":["Agent"]} |
| dibble | opencode | Use for explicit code security audits of application source, dependencies, secrets, and LLM app risks when present. | {"mode":"subagent","permission":{"question":"allow","task":"deny"}} |
| dibble | codex | Use for explicit code security audits of application source, dependencies, secrets, and LLM app risks when present. | No metadata override |
| dibble | pi | Use for explicit code security audits of application source, dependencies, secrets, and LLM app risks when present. | {"exclude_extensions":"pi-cc-header","extensions":true,"isolated":false,"prompt_mode":"replace","skills":true} |
| donatello | claude | A methodical implementation engineer who precisely executes code changes from improvement plans while maintaining existing style, verifying tests pass, and seeking clarification when obstacles arise. | {"disallowedTools":["Agent"]} |
| donatello | opencode | A methodical implementation engineer who precisely executes code changes from improvement plans while maintaining existing style, verifying tests pass, and seeking clarification when obstacles arise. | {"mode":"subagent","permission":{"question":"allow","task":"deny"}} |
| donatello | codex | A methodical implementation engineer who precisely executes code changes from improvement plans while maintaining existing style, verifying tests pass, and seeking clarification when obstacles arise. | No metadata override |
| donatello | pi | A methodical implementation engineer who precisely executes code changes from improvement plans while maintaining existing style, verifying tests pass, and seeking clarification when obstacles arise. | {"exclude_extensions":"pi-cc-header","extensions":true,"isolated":false,"prompt_mode":"replace","skills":true} |
| garfield | claude | A specialised git workflow assistant that enforces best practices for commit messages, pull requests, and code explanations while strictly adhering to Conventional Commits standards. | {"disallowedTools":["Agent"]} |
| garfield | opencode | A specialised git workflow assistant that enforces best practices for commit messages, pull requests, and code explanations while strictly adhering to Conventional Commits standards. | {"mode":"subagent","permission":{"question":"allow","task":"deny"}} |
| garfield | codex | A specialised git workflow assistant that enforces best practices for commit messages, pull requests, and code explanations while strictly adhering to Conventional Commits standards. | No metadata override |
| garfield | pi | A specialised git workflow assistant that enforces best practices for commit messages, pull requests, and code explanations while strictly adhering to Conventional Commits standards. | {"exclude_extensions":"pi-cc-header","extensions":true,"isolated":false,"prompt_mode":"replace","skills":true} |
| gonzales | claude | A pragmatic performance specialist who identifies high-impact optimisations in bottlenecks and hotspots while preserving code simplicity and focusing on user-perceivable improvements. | {"disallowedTools":["Agent"]} |
| gonzales | opencode | A pragmatic performance specialist who identifies high-impact optimisations in bottlenecks and hotspots while preserving code simplicity and focusing on user-perceivable improvements. | {"mode":"subagent","permission":{"question":"allow","task":"deny"}} |
| gonzales | codex | A pragmatic performance specialist who identifies high-impact optimisations in bottlenecks and hotspots while preserving code simplicity and focusing on user-perceivable improvements. | No metadata override |
| gonzales | pi | A pragmatic performance specialist who identifies high-impact optimisations in bottlenecks and hotspots while preserving code simplicity and focusing on user-perceivable improvements. | {"exclude_extensions":"pi-cc-header","extensions":true,"isolated":false,"prompt_mode":"replace","skills":true} |
| penfold | claude | A thoughtful research generalist who explores ideas through dialogue, synthesises findings into context-efficient overviews, and frames problems clearly for downstream specialists. | {"disallowedTools":["Agent"]} |
| penfold | opencode | A thoughtful research generalist who explores ideas through dialogue, synthesises findings into context-efficient overviews, and frames problems clearly for downstream specialists. | {"mode":"subagent","permission":{"question":"allow","task":"deny"}} |
| penfold | codex | A thoughtful research generalist who explores ideas through dialogue, synthesises findings into context-efficient overviews, and frames problems clearly for downstream specialists. | No metadata override |
| penfold | pi | A thoughtful research generalist who explores ideas through dialogue, synthesises findings into context-efficient overviews, and frames problems clearly for downstream specialists. | {"exclude_extensions":"pi-cc-header","extensions":true,"isolated":false,"prompt_mode":"replace","skills":true} |
| penry | claude | A meticulous code reviewer who identifies practical maintainability improvements through simplification, deduplication, and naming clarity while ensuring all changes are small, safe, and preserve exact functionality. | {"disallowedTools":["Agent"]} |
| penry | opencode | A meticulous code reviewer who identifies practical maintainability improvements through simplification, deduplication, and naming clarity while ensuring all changes are small, safe, and preserve exact functionality. | {"mode":"subagent","permission":{"question":"allow","task":"deny"}} |
| penry | codex | A meticulous code reviewer who identifies practical maintainability improvements through simplification, deduplication, and naming clarity while ensuring all changes are small, safe, and preserve exact functionality. | No metadata override |
| penry | pi | A meticulous code reviewer who identifies practical maintainability improvements through simplification, deduplication, and naming clarity while ensuring all changes are small, safe, and preserve exact functionality. | {"exclude_extensions":"pi-cc-header","extensions":true,"isolated":false,"prompt_mode":"replace","skills":true} |
| rosey | claude | A prompt and skill specialist who crafts, refines, and maintains agent prompts, skills, commands, and instruction files with ruthless token efficiency. | {"disallowedTools":["Agent"]} |
| rosey | opencode | A prompt and skill specialist who crafts, refines, and maintains agent prompts, skills, commands, and instruction files with ruthless token efficiency. | {"mode":"subagent","permission":{"question":"allow","task":"deny"}} |
| rosey | codex | A prompt and skill specialist who crafts, refines, and maintains agent prompts, skills, commands, and instruction files with ruthless token efficiency. | No metadata override |
| rosey | pi | A prompt and skill specialist who crafts, refines, and maintains agent prompts, skills, commands, and instruction files with ruthless token efficiency. | {"exclude_extensions":"pi-cc-header","extensions":true,"isolated":false,"prompt_mode":"replace","skills":true} |
| velma | claude | A documentation architect who creates engaging, well-organised technical documentation by translating code into clear explanations, crafting compelling READMEs, and structuring information for optimal reader comprehension. | {"disallowedTools":["Agent"]} |
| velma | opencode | A documentation architect who creates engaging, well-organised technical documentation by translating code into clear explanations, crafting compelling READMEs, and structuring information for optimal reader comprehension. | {"mode":"subagent","permission":{"question":"allow","task":"deny"}} |
| velma | codex | A documentation architect who creates engaging, well-organised technical documentation by translating code into clear explanations, crafting compelling READMEs, and structuring information for optimal reader comprehension. | No metadata override |
| velma | pi | A documentation architect who creates engaging, well-organised technical documentation by translating code into clear explanations, crafting compelling READMEs, and structuring information for optimal reader comprehension. | {"exclude_extensions":"pi-cc-header","extensions":true,"isolated":false,"prompt_mode":"replace","skills":true} |

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
| casper | claude | Unset | sonnet | high |
| casper | opencode | anthropic | claude-sonnet-5 | Unset |
| casper | opencode | openai | gpt-5.6-sol | Unset |
| casper | codex | Unset | gpt-5.6-sol | medium |
| casper | pi | anthropic | claude-sonnet-5 | high |
| casper | pi | openai-codex | gpt-5.6-sol | medium |
| dibble | claude | Unset | Unset | Unset |
| dibble | opencode | Unset | Unset | Unset |
| dibble | codex | Unset | Unset | Unset |
| dibble | pi | Unset | Unset | Unset |
| donatello | claude | Unset | Unset | Unset |
| donatello | opencode | Unset | Unset | Unset |
| donatello | codex | Unset | Unset | Unset |
| donatello | pi | Unset | Unset | Unset |
| garfield | claude | Unset | haiku | Unset |
| garfield | opencode | anthropic | claude-haiku-4-5 | Unset |
| garfield | opencode | openai | gpt-5.6-luna | Unset |
| garfield | codex | Unset | gpt-5.6-luna | medium |
| garfield | pi | anthropic | claude-haiku-4-5 | Unset |
| garfield | pi | google | gemini-3-flash | Unset |
| garfield | pi | openai-codex | gpt-5.6-luna | medium |
| gonzales | claude | Unset | Unset | Unset |
| gonzales | opencode | Unset | Unset | Unset |
| gonzales | codex | Unset | Unset | Unset |
| gonzales | pi | Unset | Unset | Unset |
| penfold | claude | Unset | claude-fable-5-1 | high |
| penfold | opencode | anthropic | claude-fable-5-1 | Unset |
| penfold | opencode | openai | gpt-6-astra | Unset |
| penfold | codex | Unset | gpt-6-astra | medium |
| penfold | pi | anthropic | claude-fable-5-1 | high |
| penfold | pi | openai-codex | gpt-6-astra | medium |
| penry | claude | Unset | Unset | Unset |
| penry | opencode | Unset | Unset | Unset |
| penry | codex | Unset | Unset | Unset |
| penry | pi | Unset | Unset | Unset |
| rosey | claude | Unset | Unset | Unset |
| rosey | opencode | Unset | Unset | Unset |
| rosey | codex | Unset | Unset | Unset |
| rosey | pi | Unset | Unset | Unset |
| velma | claude | Unset | sonnet | high |
| velma | opencode | anthropic | claude-sonnet-5 | Unset |
| velma | opencode | openai | gpt-5.6-sol | Unset |
| velma | codex | Unset | gpt-5.6-sol | medium |
| velma | pi | anthropic | claude-sonnet-5 | high |
| velma | pi | openai-codex | gpt-5.6-sol | medium |
