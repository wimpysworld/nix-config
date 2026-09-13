import assert from "node:assert/strict";
import { test } from "node:test";
import register from "./index.ts";

const beta = "fast-mode-2026-02-01";
const definitions = {
	openai: ["openai-responses", "https://api.openai.com/v1", "gpt-6-astra"],
	"openai-codex": [
		"openai-codex-responses",
		"https://chatgpt.com/backend-api",
		"gpt-6-astra",
	],
	anthropic: [
		"anthropic-messages",
		"https://api.anthropic.com",
		"claude-opus-5",
	],
};
function model(provider, id = definitions[provider]?.[2]) {
	const [api, baseUrl] = definitions[provider] ?? [
		"unknown",
		"https://example.com",
	];
	return Object.freeze({ provider, id, api, baseUrl });
}
function harness(selected = model("openai")) {
	const hooks = new Map();
	const commands = new Map();
	const notifications = [];
	const statuses = new Map();
	const forbidden = () =>
		assert.fail("Model, thinking, or persistent state changed");
	register({
		on: (name, handler) => hooks.set(name, handler),
		registerCommand: (name, command) => commands.set(name, command),
		setModel: forbidden,
		setThinkingLevel: forbidden,
		appendEntry: forbidden,
	});
	const ctx = {
		model: selected,
		thinkingLevel: "high",
		hasUI: true,
		modelRegistry: { find: () => ctx.model },
		sessionManager: { getEntries: forbidden, getBranch: forbidden },
		waitForIdle: async () => {},
		ui: {
			setStatus: (key, text) => statuses.set(key, text),
			notify: (text) => notifications.push(text),
		},
	};
	const emit = (name, event = {}) => hooks.get(name)(event, ctx);
	return {
		ctx,
		emit,
		notifications,
		command: (args) => commands.get("fast").handler(args, ctx),
		status: () => statuses.get("noughty-service-tier:status"),
		request: (payload = {}) =>
			emit("before_provider_request", { payload }) ?? payload,
		headers: (headers) => {
			emit("before_provider_headers", { headers });
			return headers;
		},
	};
}

for (const provider of Object.keys(definitions)) {
	test(`${provider}: explicit on/off, status, and unchanged model/thinking`, async () => {
		const h = harness(model(provider));
		const original = h.ctx.model;
		h.emit("session_start", { reason: "startup" });
		for (const command of [
			"",
			"status",
			"on",
			"on",
			"status",
			"",
			"off",
			"off",
		]) {
			await h.command(command);
			const on =
				h.status().startsWith("Requested priority") ||
				h.status().startsWith("Requested fast;");
			const result = h.request({
				service_tier: "flex",
				speed: "fast",
				reasoning: { effort: "high" },
			});
			if (provider === "anthropic") {
				assert.equal(result.service_tier, "standard_only");
				assert.equal(result.speed, on ? "fast" : undefined);
			} else {
				assert.equal(
					result.service_tier,
					on ? "priority" : provider === "openai" ? "default" : undefined,
				);
			}
			assert.deepEqual(result.reasoning, { effort: "high" });
			assert.equal(h.ctx.model, original);
			assert.equal(h.ctx.thinkingLevel, "high");
		}
	});
}
for (const reason of ["startup", "new", "resume", "fork", "reload"]) {
	test(`${reason} resets prior Fast without reading history`, async () => {
		const h = harness();
		await h.command("on");
		assert.equal(h.request().service_tier, "priority");
		h.emit("session_start", { reason });
		assert.equal(h.request().service_tier, "default");
	});
}
test("separate factories, children, and a replacement reload start off", async () => {
	const parent = harness();
	await parent.command("on");
	for (const reason of ["startup", "resume", "fork", "reload"]) {
		const child = harness();
		child.emit("session_start", { reason });
		assert.equal(child.request().service_tier, "default");
		assert.equal(parent.request().service_tier, "priority");
	}
});
test("invalid arguments never change Fast", async () => {
	const h = harness();
	for (const initial of ["off", "on"]) {
		await h.command(initial);
		const before = h.request();
		for (const args of ["toggle", "ON", "off now", "status extra", "on\noff"]) {
			await h.command(args);
			assert.deepEqual(h.request(), before);
			assert.match(h.notifications.at(-1), /No change/);
		}
	}
});
test("model, provider, endpoint, and unannounced changes reset Fast", async () => {
	const h = harness();
	for (const next of [
		model("openai", "gpt-5.6-sol"),
		model("anthropic"),
		model("openai-codex"),
	]) {
		await h.command("on");
		h.ctx.model = next;
		h.emit("model_select", { model: next });
		assert.notEqual(h.request().service_tier, "priority");
		assert.equal(h.request().speed, undefined);
	}
	await h.command("on");
	h.ctx.model = model("openai", "gpt-5.6-terra");
	assert.equal(h.request().service_tier, "default");
	await h.command("on");
	h.ctx.model = { ...h.ctx.model, baseUrl: "https://example.com" };
	assert.deepEqual(h.request(), {});
	assert.match(h.status(), /standard not enforced/);
});
test("Anthropic pairs header/body controls and preserves unrelated values", async () => {
	const h = harness(model("anthropic"));
	for (const command of ["off", "on", "off"]) {
		await h.command(command);
		const headers = h.headers({
			"Anthropic-Beta": `other-beta, ${beta},${beta}-extra`,
			"anthropic-beta": `another-beta,${beta}`,
			"x-test": "keep",
		});
		assert.equal(headers["Anthropic-Beta"], null);
		assert.equal(headers["x-test"], "keep");
		assert.deepEqual(headers["anthropic-beta"].split(","), [
			"other-beta",
			`${beta}-extra`,
			"another-beta",
			...(command === "on" ? [beta] : []),
		]);
		const input = Object.freeze({
			speed: "fast",
			service_tier: "auto",
			messages: [{ role: "user", content: "test" }],
			thinking: { type: "adaptive" },
		});
		const output = h.request(input);
		assert.equal(output.speed, command === "on" ? "fast" : undefined);
		assert.equal(output.service_tier, "standard_only");
		assert.equal(output.messages, input.messages);
		assert.equal(output.thinking, input.thinking);
	}
	assert.equal(h.headers({ "anthropic-beta": beta })["anthropic-beta"], null);
	assert.equal(h.headers({})["anthropic-beta"], null);
});
test("unknown providers and APIs remain untouched and unavailable", async () => {
	for (const selected of [
		undefined,
		model("other", "gpt-6-astra"),
		{ ...model("openai"), api: "openai-completions" },
	]) {
		const h = harness();
		h.ctx.model = selected;
		await h.command("on");
		const input = { service_tier: "flex" };
		assert.equal(h.request(input), input);
		assert.match(h.status(), /Fast unavailable; standard not enforced/);
	}
});
test("unsupported and unregistered models cannot enable Fast", async () => {
	for (const selected of [
		model("openai", "gpt-future"),
		model("openai-codex", "gpt-future"),
		...[
			"claude-opus-4-6",
			"claude-opus-4-7",
			"claude-fable-5-1",
			"claude-sonnet-5",
			"claude-haiku-4-5-20251001",
		].map((id) => model("anthropic", id)),
	]) {
		const h = harness(selected);
		await h.command("on");
		assert.match(h.status(), /Fast unavailable/);
		assert.notEqual(h.request().service_tier, "priority");
		assert.equal(h.request().speed, undefined);
		assert.equal(
			h.headers({ "anthropic-beta": beta })["anthropic-beta"],
			selected.provider === "anthropic" ? null : beta,
		);
	}
	const h = harness();
	h.ctx.modelRegistry.find = () => undefined;
	await h.command("on");
	assert.match(h.status(), /Fast unavailable/);
});
test("Anthropic header removals precede additions for either key order", async () => {
	const h = harness(model("anthropic"));
	await h.command("on");
	for (const entries of [
		[
			["anthropic-beta", "keep"],
			["Anthropic-Beta", beta],
		],
		[
			["Anthropic-Beta", beta],
			["anthropic-beta", "keep"],
		],
	]) {
		const headers = h.headers(Object.fromEntries(entries));
		const applied = new Headers();
		for (const [key, value] of Object.entries(headers)) {
			if (value === null) applied.delete(key);
			else applied.set(key, value);
		}
		assert.equal(applied.get("anthropic-beta"), `keep,${beta}`);
	}
});
test("Fast changes wait until paired request hooks finish", async () => {
	const h = harness(model("anthropic"));
	let finish;
	h.ctx.waitForIdle = () =>
		new Promise((resolve) => {
			finish = resolve;
		});
	const pending = h.command("on");
	assert.equal(h.headers({})["anthropic-beta"], null);
	assert.equal(h.request().speed, undefined);
	finish();
	await pending;
	assert.equal(h.headers({})["anthropic-beta"], beta);
	assert.equal(h.request().speed, "fast");
});
test("all verified exact IDs enable Fast", async () => {
	for (const provider of ["openai", "openai-codex"]) {
		for (const id of [
			"gpt-6-astra",
			"gpt-5.6-sol",
			"gpt-5.6-terra",
			"gpt-5.6-luna",
		]) {
			const h = harness(model(provider, id));
			await h.command("on");
			assert.equal(h.request().service_tier, "priority");
		}
	}
	for (const id of ["claude-opus-5", "claude-opus-4-8"]) {
		const h = harness(model("anthropic", id));
		await h.command("on");
		assert.equal(h.request().speed, "fast");
		assert.equal(h.headers({})["anthropic-beta"], beta);
	}
});
test("malformed payloads are unchanged and no-UI operation is safe", () => {
	const h = harness();
	h.ctx.hasUI = false;
	h.ctx.ui = new Proxy({}, { get: () => assert.fail("UI called without UI") });
	h.emit("session_start");
	for (const payload of [null, [], "text", 4])
		assert.equal(h.request(payload), payload);
	h.emit("session_shutdown");
});
