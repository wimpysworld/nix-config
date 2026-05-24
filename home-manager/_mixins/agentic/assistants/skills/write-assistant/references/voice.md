# Voice rewrites

Imperative beats descriptive. Specific beats vague. Examples below.

## Imperative vs descriptive

| Don't                                    | Do                           |
| ---------------------------------------- | ---------------------------- |
| "You should focus on type safety."       | "Focus on type safety."      |
| "The agent will identify bugs."          | "Identify bugs."             |
| "It is recommended to read tests first." | "Read tests first."          |
| "Try to keep responses concise."         | "Keep responses ≤200 words." |
| "Be helpful and friendly."               | Cut. Generic LLM behaviour.  |

## Specific vs vague

| Don't                          | Do                                             |
| ------------------------------ | ---------------------------------------------- |
| "Recent files."                | "Files changed in the last 5 commits."         |
| "When appropriate, add tests." | "Add a unit test for every new exported func." |
| "Reasonable response length."  | "Response ≤400 words for review tasks."        |
| "High-impact changes."         | "Changes that reduce p99 latency by ≥10%."     |

## Decision criteria

Replace "if needed", "as required", "when relevant" with explicit triggers.

| Don't                           | Do                                                                  |
| ------------------------------- | ------------------------------------------------------------------- |
| "Load the nix skill if needed." | "Load the nix skill when the task mentions Nix, NixOS, or `.nix`."  |
| "Use examples if relevant."     | "Include 1-2 examples for style or judgment tasks; omit otherwise." |

## Aggressive language

Anthropic Opus 4.5+ and Sonnet 4.6 over-trigger on caps. Dial back:

| Don't                        | Do                                 |
| ---------------------------- | ---------------------------------- |
| "IMPORTANT: never delete X." | "Never delete X."                  |
| "YOU MUST run tests first."  | "Run tests before reporting done." |
| "ALWAYS cite sources."       | "Cite sources for each claim."     |

## First person

Cut every "I will", "I'll", "My job is".

| Don't                         | Do                  |
| ----------------------------- | ------------------- |
| "I will analyse the code."    | "Analyse the code." |
| "My role is to review tests." | "You review tests." |

## Output format

Show the shape; don't describe it.

| Don't                                | Do                                             |
| ------------------------------------ | ---------------------------------------------- |
| "Respond with a structured summary." | A fenced Markdown template the agent fills in. |
| "Return findings in a clear format." | A table with the required columns.             |
