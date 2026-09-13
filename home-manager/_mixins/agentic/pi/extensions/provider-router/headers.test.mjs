import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import {
	mkdtempSync,
	mkdirSync,
	readFileSync,
	rmSync,
	symlinkSync,
	writeFileSync,
} from "node:fs";
import { homedir, tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { test } from "node:test";

const packageDir =
	process.env.PI_SUBAGENTS_DIR ??
	join(homedir(), ".pi/agent/npm/node_modules/@tintinweb/pi-subagents");
const { loadCustomAgents } = await import(
	pathToFileURL(join(packageDir, "src/custom-agents.ts")).href
);
const directory = dirname(fileURLToPath(import.meta.url));
const repo = resolve(directory, "../../../../../..");
const assistants = join(repo, "home-manager/_mixins/agentic/assistants");

test("upstream loads all generated native headers through symlinks", () => {
	const fixture = mkdtempSync(join(tmpdir(), "tintinweb-headers-"));
	const original = process.env.PI_CODING_AGENT_DIR;
	try {
		process.env.PI_CODING_AGENT_DIR = join(fixture, "user");
		const agentsDir = join(fixture, ".pi/agents");
		mkdirSync(agentsDir, { recursive: true });
		const expression = `let flake = builtins.getFlake ${JSON.stringify(repo)};
lib = flake.inputs.nixpkgs.lib;
c = import ${assistants}/compose.nix { inherit lib; };
in c.composeAgents "pi"`;
		const generated = JSON.parse(
			execFileSync("nix", ["eval", "--impure", "--json", "--expr", expression], {
				encoding: "utf8",
			}),
		);
		for (const [name, content] of Object.entries(generated)) {
			const target = join(fixture, `${name}.md`);
			writeFileSync(target, content);
			symlinkSync(target, join(agentsDir, `${name}.md`));
		}
		const loaded = loadCustomAgents(fixture, true);
		assert.equal(loaded.size, 11);
		for (const [name, agent] of loaded) {
			assert.equal(agent.promptMode, "replace", name);
			assert.equal(agent.extensions, true, name);
			assert.equal(agent.skills, true, name);
			assert.equal(agent.isolated, false, name);
			assert.equal(agent.inheritContext, undefined, name);
			assert.equal(agent.enabled, true, name);
			assert.equal(agent.model, undefined, name);
			assert.ok(
				agent.systemPrompt.startsWith(
					readFileSync(join(assistants, "agents", name, "prompt.md"), "utf8").trim(),
				),
				name,
			);
			assert.match(agent.systemPrompt, /You are a leaf worker\./);
			assert.match(agent.systemPrompt, /## Shared safety rules/);
		}
	} finally {
		if (original === undefined) delete process.env.PI_CODING_AGENT_DIR;
		else process.env.PI_CODING_AGENT_DIR = original;
		rmSync(fixture, { recursive: true, force: true });
	}
});
