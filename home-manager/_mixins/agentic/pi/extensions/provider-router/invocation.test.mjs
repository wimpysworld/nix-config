import assert from "node:assert/strict";
import { mkdtempSync, mkdirSync, writeFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { pathToFileURL } from "node:url";
import { after, test } from "node:test";

const home = mkdtempSync(join(tmpdir(), "pi-invocation-"));
after(() => rmSync(home, { recursive: true, force: true }));
const dir = join(home, ".pi/agent/extensions/provider-router");
mkdirSync(dir, { recursive: true });
writeFileSync(
	join(dir, "routes.json"),
	JSON.stringify({
		commands: {
			review: {
				providers: { "openai-codex": { model: "command", thinking: "high" } },
			},
			missing: { providers: { "openai-codex": { model: "missing" } } },
		},
		skills: {
			focused: {
				providers: { "openai-codex": { model: "skill", thinking: "low" } },
			},
		},
	}),
);
const originalHome = process.env.HOME;
process.env.HOME = home;
const { default: registerRouter } = await import("./index.ts");
const { default: registerDisplay } =
	await import("../prompt-template-display/index.ts");
if (originalHome === undefined) delete process.env.HOME;
else process.env.HOME = originalHome;

function harness(display = false) {
	const handlers = new Map();
	const notifications = [];
	const sent = [];
	const models = ["parent", "command", "skill", "user"].map((id) => ({
		id,
		provider: "openai-codex",
	}));
	let model = models[0];
	let thinking = "medium";
	let aborted = false;
	const ctx = {
		get model() {
			return model;
		},
		mode: "tui",
		isIdle: () => true,
		abort: () => {
			aborted = true;
		},
		modelRegistry: {
			getAvailable: () => models,
			find: (provider, id) =>
				models.find((item) => item.provider === provider && item.id === id),
		},
		ui: { notify: (message) => notifications.push(message) },
	};
	const emit = async (name, event) => {
		for (const handler of handlers.get(name) ?? []) {
			const result = await handler(event, ctx);
			if (result?.action === "handled" || result?.block) return result;
		}
	};
	const pi = {
		events: {
			on: (name, fn) => {
				handlers.set(name, [fn]);
				return () => handlers.delete(name);
			},
			emit: (name, data) => {
				for (const fn of handlers.get(name) ?? []) fn(data);
			},
		},
		on: (name, handler) =>
			handlers.set(name, [...(handlers.get(name) ?? []), handler]),
		setModel: async (next) => {
			model = next;
			await emit("model_select", { source: "set", model });
			return true;
		},
		getThinkingLevel: () => thinking,
		setThinkingLevel: (level) => {
			thinking = level;
		},
		registerEntryRenderer: () => {},
		getCommands: () =>
			["review", "missing"].map((name) => ({
				name,
				source: "prompt",
				sourceInfo: { source: "file", path: join(home, "template.md") },
			})),
		appendEntry: () => {},
		sendUserMessage: (content) => sent.push(content),
		sendMessage: (content) => sent.push(content),
	};
	writeFileSync(join(home, "template.md"), "Perform the task.");
	if (display) registerDisplay(pi);
	registerRouter(pi);
	return {
		emit,
		pi,
		ctx,
		notifications,
		sent,
		get aborted() {
			return aborted;
		},
	};
}

test("routes a display-consumed command and restores the session", async () => {
	const h = harness(true);
	await h.emit("input", { text: "/review", source: "interactive" });
	assert.equal(h.ctx.model.id, "parent");
	await h.emit("before_agent_start", {});
	await h.emit("agent_start", {});
	assert.equal(h.ctx.model.id, "command");
	assert.equal(h.pi.getThinkingLevel(), "high");
	assert.equal(h.sent.length, 1);
	await h.emit("agent_end", {});
	assert.equal(h.ctx.model.id, "command");
	await h.emit("agent_settled", {});
	assert.equal(h.ctx.model.id, "parent");
	assert.equal(h.pi.getThinkingLevel(), "medium");
});

test("direct skill invocation routes but supporting reads do not", async () => {
	const h = harness();
	await h.emit("tool_call", {
		toolName: "read",
		input: { path: "focused/SKILL.md" },
	});
	assert.equal(h.ctx.model.id, "parent");
	await h.emit("input", { text: "/skill:focused task", source: "interactive" });
	await h.emit("before_agent_start", {});
	await h.emit("agent_start", {});
	assert.equal(h.ctx.model.id, "skill");
	await h.emit("agent_settled", {});
	assert.equal(h.ctx.model.id, "parent");
});

test("a user model choice wins and prevents stale restoration", async () => {
	const h = harness();
	await h.emit("input", { text: "/review", source: "interactive" });
	await h.emit("before_agent_start", {});
	await h.emit("agent_start", {});
	await h.pi.setModel({ provider: "openai-codex", id: "user" });
	await h.emit("agent_settled", {});
	await h.emit("input", { text: "/review", source: "interactive" });
	assert.equal(h.ctx.model.id, "user");
});

test("an explicit model choice cancels a staged route", async () => {
	const h = harness();
	await h.emit("input", { text: "/review" });
	await h.pi.setModel({ provider: "openai-codex", id: "user" });
	await h.emit("before_agent_start", {});
	await h.emit("agent_start", {});
	await h.emit("agent_settled", {});
	assert.equal(h.ctx.model.id, "user");
});

test("a failed preflight leaves no model change or route on the next input", async () => {
	const h = harness();
	await h.emit("input", { text: "/review" });
	assert.equal(h.ctx.model.id, "parent");
	await h.emit("input", { text: "ordinary prompt" });
	await h.emit("before_agent_start", {});
	await h.emit("agent_start", {});
	assert.equal(h.ctx.model.id, "parent");
});

test("failed model selection aborts the run and restores session settings", async () => {
	const h = harness();
	const setModel = h.pi.setModel;
	h.pi.setModel = async (model) =>
		model.id === "command" ? false : setModel(model);
	await h.emit("input", { text: "/review" });
	await h.emit("before_agent_start", {});
	await h.emit("agent_start", {});
	assert.equal(h.aborted, true);
	assert.equal(h.ctx.model.id, "parent");
	assert.equal(h.pi.getThinkingLevel(), "medium");
	assert.match(h.notifications[0], /could not select routed model/);
});

for (const continuation of [
	"HTTP retry",
	"overflow recovery",
	"queued follow-up",
]) {
	test(`keeps the route across ${continuation} until settlement`, async () => {
		const h = harness();
		await h.emit("input", { text: "/review" });
		await h.emit("before_agent_start", {});
		await h.emit("agent_start", {});
		await h.emit("agent_end", {});
		await h.emit("before_agent_start", {});
		await h.emit("agent_start", {});
		assert.equal(h.ctx.model.id, "command");
		assert.equal(h.pi.getThinkingLevel(), "high");
		await h.emit("agent_end", {});
		await h.emit("agent_settled", {});
		assert.equal(h.ctx.model.id, "parent");
		assert.equal(h.pi.getThinkingLevel(), "medium");
	});
}

test("cancellation and thrown run errors restore at settlement", async () => {
	for (const reason of ["aborted", "error"]) {
		const h = harness();
		await h.emit("input", { text: "/review" });
		await h.emit("before_agent_start", {});
		await h.emit("agent_start", {});
		await h.emit("agent_end", { messages: [{ stopReason: reason }] });
		await h.emit("agent_settled", {});
		assert.equal(h.ctx.model.id, "parent");
	}
});

test("unsupported model effort blocks direct skill input", async () => {
	const h = harness();
	h.ctx.modelRegistry.find("openai-codex", "skill").supportedThinking = ["off"];
	await h.emit("input", { text: "/skill:focused", source: "interactive" });
	assert.equal(h.ctx.model.id, "parent");
	assert.match(h.notifications[0], /does not support thinking level low/);
});

test("display-consumed unavailable and streaming routes never dispatch", async () => {
	for (const event of [
		{ text: "/missing" },
		{ text: "/review", streamingBehavior: "steer" },
	]) {
		const h = harness(true);
		await h.emit("input", { ...event, source: "interactive" });
		assert.equal(h.sent.length, 0);
		assert.equal(h.ctx.model.id, "parent");
		assert.equal(h.notifications.length, 1);
	}
});

const nativeDirectory = process.env.PI_CODING_AGENT_DIR;
test(
	"native Pi applies routes after preflight and keeps them through retries",
	{
		skip:
			!nativeDirectory &&
			"Set PI_CODING_AGENT_DIR to test the installed Pi runtime",
	},
	async () => {
		const { AgentSession } = await import(
			pathToFileURL(join(nativeDirectory, "dist/core/agent-session.js"))
		);
		const { Agent } = await import(
			pathToFileURL(
				join(
					nativeDirectory,
					"node_modules/@earendil-works/pi-agent-core/dist/agent.js",
				),
			)
		);
		for (const outcome of [
			"success",
			"retry",
			"overflow",
			"aborted",
			"throw",
			"preflight",
		]) {
			const h = harness();
			const requests = [];
			const session = Object.create(AgentSession.prototype);
			const agent = new Agent({
				initialState: {
					model: h.ctx.model,
					thinkingLevel: "medium",
					systemPrompt: "base",
				},
				streamFn: (model, context, options) => {
					requests.push({
						model: model.id,
						context,
						reasoning: options.reasoning,
					});
					if (outcome === "throw")
						throw new Error("synthetic transport failure");
					const failed =
						requests.length === 1 && ["retry", "overflow"].includes(outcome);
					const message = {
						role: "assistant",
						provider: model.provider,
						model: model.id,
						api: "openai-responses",
						content: [],
						timestamp: Date.now(),
						stopReason: failed
							? "error"
							: outcome === "aborted"
								? "aborted"
								: "stop",
						errorMessage: failed
							? outcome === "retry"
								? "503 Service Unavailable"
								: "context window exceeded"
							: undefined,
						usage: {
							input: 0,
							output: 0,
							totalTokens: 0,
							cacheRead: 0,
							cacheWrite: 0,
						},
					};
					return {
						async *[Symbol.asyncIterator]() {
							yield { type: "done", message };
						},
						result: async () => message,
					};
				},
			});
			const setModel = h.pi.setModel;
			h.pi.setModel = async (model) => {
				agent.state.model = model;
				return setModel(model);
			};
			const setThinking = h.pi.setThinkingLevel;
			h.pi.setThinkingLevel = (thinking) => {
				agent.state.thinkingLevel = thinking;
				setThinking(thinking);
			};
			h.ctx.abort = () => agent.abort();
			let compacted = false;
			Object.assign(session, {
				agent,
				_retryAttempt: 0,
				_pendingNextTurnMessages: [],
				_baseSystemPrompt: "base",
				settingsManager: {
					getRetrySettings: () => ({
						enabled: true,
						maxRetries: 1,
						baseDelayMs: 0,
					}),
					getCompactionSettings: () => ({ enabled: false }),
				},
				_modelRuntime: {
					hasConfiguredAuth: () => outcome !== "preflight",
					checkAuth: async () => undefined,
					isUsingOAuth: () => false,
				},
				_emit() {},
				_flushPendingBashMessages() {},
				_flushPendingCustomMessages() {},
				_compactBeforeNextAssistantResponse: async (context) => context,
				_checkCompaction: async () => {
					if (outcome !== "overflow" || compacted) return false;
					compacted = true;
					agent.state.messages.pop();
					return true;
				},
				_extensionRunner: {
					hasHandlers: () => true,
					emitInput: async (text) =>
						(await h.emit("input", { text })) ?? { action: "continue" },
					emitBeforeAgentStart: async () => h.emit("before_agent_start", {}),
					emit: (event) => h.emit(event.type, event),
				},
			});
			session._installAgentNextTurnRefresh();
			agent.subscribe(async (event) => {
				if (event.type === "message_end" && event.message.role === "assistant")
					session._lastAssistantMessage = event.message;
				await h.emit(event.type, event);
			});
			if (outcome === "preflight") {
				await assert.rejects(
					session.prompt("/review", { expandPromptTemplates: false }),
					/No API key/,
				);
				assert.equal(requests.length, 0);
			} else {
				await session.prompt("/review", { expandPromptTemplates: false });
				assert.equal(
					requests.length,
					["retry", "overflow"].includes(outcome) ? 2 : 1,
					outcome,
				);
				assert.ok(
					requests.every((request) => request.model === "command"),
					outcome,
				);
				assert.ok(
					requests.every((request) => request.reasoning === "high"),
					outcome,
				);
				assert.ok(
					requests.every((request) => request.context.systemPrompt === "base"),
					outcome,
				);
			}
			assert.equal(h.ctx.model.id, "parent", outcome);
			assert.equal(h.pi.getThinkingLevel(), "medium", outcome);
		}
	},
);
