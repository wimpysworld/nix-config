---
name: meet-the-agents
description: Registry of available specialist agents and their task domains. Load when delegating a task, selecting an agent, or unsure which agent to use.
user-invocable: false
---

## Agent Registry

| Agent | Role | Delegate when... |
|-------|------|-----------------|
| **traya** | Principal assistant & orchestrator | **Default agent.** Coordinates all specialist agents, manages delegation, context-aware task routing |
| **batfink** | Infrastructure security auditor | Infrastructure hardening, container/cloud/network security, blast radius assessment |
| **brain** | Test engineer | Writing unit tests, analysing coverage, identifying untested code paths |
| **casper** | Technical writer (Linux/open-source, Martin's voice) | Blog posts, Linux content, open-source documentation in a British style |
| **dexter** | Nix specialist | Nix packages, NixOS modules, Home Manager config, nix-darwin, flakes - **always prefer over Donatello for any `.nix` file changes** |
| **dibble** | Code security auditor | Source code vulnerabilities, insecure patterns, dependency risks, secrets detection |
| **donatello** | Implementation engineer | Executing a defined plan precisely, making targeted code changes in non-Nix files |
| **garfield** | Git workflow | Commit messages, pull requests, branch naming, conventional commits |
| **gonzales** | Performance specialist | Profiling, optimisation, bottleneck analysis |
| **melody** | Audio assessment | Interpreting audio metrics, voice recording quality |
| **penfold** | Research generalist | Exploring ideas, synthesising findings, framing problems |
| **penry** | Code reviewer | Maintainability improvements, simplification, deduplication, naming clarity |
| **pepe** | LÖVE 2D / Lua game dev | Lua 5.1 game code, LÖVE 2D APIs, game performance |
| **rosey** | Prompt & skill specialist | Crafting/refining agent prompts, creating and updating skills, commands, and instruction files |
| **velma** | Documentation architect | READMEs, technical docs, structured reference documentation |

## Delegation Pattern

Once a pattern is established, propose delegation by default:
- "Shall I delegate to Garfield for a commit message?"
- "Shall I ask Dexter to implement this Nix change?"

Do not ask whether to act - ask whether to delegate to the appropriate agent.
