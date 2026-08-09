// @ts-nocheck
import * as assert from "node:assert/strict";
import { mkdtemp, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { afterEach, test } from "node:test";
import register from "./index.ts";

const tempDirs = [];
afterEach(async () =>
	Promise.all(
		tempDirs.splice(0).map((dir) => rm(dir, { recursive: true, force: true })),
	),
);

async function template(content) {
	const dir = await mkdtemp(join(tmpdir(), "prompt-display-"));
	tempDirs.push(dir);
	const file = join(dir, "command.md");
	await writeFile(file, content);
	return file;
}

function harness(commands = []) {
	const entries = [];
	const handlers = {};
	const sent = [];
	const sentUsers = [];
	const notifications = [];
	let renderer;
	let beforeAgentStarts = 0;
	const pi = {
		getCommands: () => commands,
		registerEntryRenderer: (_type, value) => {
			renderer = value;
		},
		on: (event, value) => {
			handlers[event] = value;
		},
		appendEntry: (type, data) => entries.push({ type, data }),
		sendMessage: (message, options) => {
			sent.push({ message, options });
		},
		sendUserMessage: (content, options) => {
			sentUsers.push({ content, options });
		},
	};
	register(pi);
	const invoke = (event, mode = "tui") =>
		handlers.input(event, {
			mode,
			ui: { notify: (...args) => notifications.push(args) },
		});
	const before = async (prompt, images) => {
		beforeAgentStarts += 1;
		return handlers.before_agent_start({ prompt, images }, {});
	};
	const context = (messages) => handlers.context({ messages }, {});
	return {
		before,
		commands,
		context,
		entries,
		get beforeAgentStarts() {
			return beforeAgentStarts;
		},
		invoke,
		notifications,
		get renderer() {
			return renderer;
		},
		sent,
		sentUsers,
	};
}

function prompt(name, path, source = "file") {
	return { name, source: "prompt", sourceInfo: { path, source } };
}
const baseEvent = {
	source: "interactive",
	text: "/task",
	images: undefined,
	streamingBehavior: undefined,
};

function rawUser(content) {
	return { role: "user", content, timestamp: 1 };
}

test("expands an idle prompt and returns a hidden before_agent_start marker", async () => {
	const file = await template(
		"---\r\ndescription: test\r\n---\r\n$1|$2|$9|$@|$ARGUMENTS|${1:-x}|${9:-x}|${@:-x}|${ARGUMENTS:-x}|${@:2}|${@:2:2}|${@:0:1}",
	);
	const h = harness([]);
	h.commands.push(prompt("dynamic", file));
	const command = `/dynamic one "two words" 'three words' four`;
	assert.deepEqual(await h.invoke({ ...baseEvent, text: command }), {
		action: "handled",
	});
	assert.equal(h.sent.length, 0);
	assert.deepEqual(h.sentUsers[0], {
		content: [{ type: "text", text: command }],
		options: undefined,
	});
	assert.equal(h.entries.length, 0);
	assert.equal(h.beforeAgentStarts, 0);
	const result = await h.before(command);
	assert.equal(
		result.message.content,
		"one|two words||one two words three words four|one two words three words four|one|x|one two words three words four|one two words three words four|two words three words four|two words three words|one",
	);
	assert.equal(result.message.display, false);
	assert.deepEqual(result.message.details, { command });
	assert.equal(h.beforeAgentStarts, 1);
	assert.equal(await h.before(command), undefined);
});

test("rewrites the paired raw user message and removes the idle marker", async () => {
	const h = harness();
	const marker = {
		role: "custom",
		customType: "prompt-template-expanded",
		content: "Expanded request",
		details: { command: "/task original" },
	};
	const earlier = rawUser("earlier");
	const expandedUser = {
		role: "user",
		content: [{ type: "text", text: "Expanded request" }],
		timestamp: 1,
	};
	assert.deepEqual(
		(await h.context([earlier, rawUser("/task original"), marker])).messages,
		[earlier, expandedUser],
	);
	assert.deepEqual(
		(await h.context([rawUser("/task original"), rawUser("nearer"), marker]))
			.messages,
		[rawUser("/task original"), expandedUser],
	);
});

test("clears a pending idle prompt when before_agent_start does not match", async () => {
	const file = await template("Expanded request");
	const h = harness([prompt("task", file)]);
	assert.deepEqual(await h.invoke(baseEvent), { action: "handled" });
	assert.equal(await h.before("different prompt"), undefined);
	assert.equal(await h.before("/task"), undefined);
});

test("preserves images on the normal expanded user message", async () => {
	const file = await template("Look closely");
	const image = { type: "image", data: "abc", mimeType: "image/png" };
	const h = harness([prompt("task", file)]);
	assert.deepEqual(await h.invoke({ ...baseEvent, images: [image] }), {
		action: "handled",
	});
	assert.deepEqual(h.sentUsers[0].content, [
		{ type: "text", text: "/task" },
		image,
	]);
	const start = await h.before("/task", [image]);
	const result = await h.context([
		rawUser(h.sentUsers[0].content),
		{
			role: "custom",
			customType: start.message.customType,
			content: start.message.content,
			details: start.message.details,
		},
	]);
	assert.deepEqual(result.messages, [
		{
			role: "user",
			content: [{ type: "text", text: "Look closely" }, image],
			timestamp: 1,
		},
	]);
});

test("uses defaults without arguments and does not recursively substitute values", async () => {
	const file = await template("${@:-fallback}/${ARGUMENTS:-fallback}/$1/$@");
	const h = harness([prompt("task", file)]);
	assert.deepEqual(await h.invoke({ ...baseEvent, text: "/task" }), {
		action: "handled",
	});
	assert.equal(
		(await h.before("/task")).message.content,
		"fallback/fallback//",
	);
	const h2 = harness([prompt("task", file)]);
	assert.deepEqual(
		await h2.invoke({ ...baseEvent, text: "/task '$2' '$ARGUMENTS'" }),
		{ action: "handled" },
	);
	assert.equal(
		(await h2.before("/task '$2' '$ARGUMENTS'")).message.content,
		"$2 $ARGUMENTS/$2 $ARGUMENTS/$2/$2 $ARGUMENTS",
	);
});

test("keeps the hidden custom message path for steer and followUp", async () => {
	const file = await template("Look");
	const image = { type: "image", data: "abc", mimeType: "image/png" };
	for (const streamingBehavior of ["steer", "followUp"]) {
		const h = harness([prompt("task", file)]);
		assert.deepEqual(
			await h.invoke({ ...baseEvent, images: [image], streamingBehavior }),
			{ action: "handled" },
		);
		assert.deepEqual(h.sent[0].message.content, [
			{ type: "text", text: "Look" },
			image,
		]);
		assert.deepEqual(h.sent[0].options, { deliverAs: streamingBehavior });
		assert.deepEqual(h.entries[0].data, { command: "/task" });
		assert.equal(h.sentUsers.length, 0);
	}
});

test("passes through SDK prompts and other unsupported input", async () => {
	const file = await template("Body");
	const h = harness([
		prompt("task", "/virtual/sdk.md", "sdk"),
		{
			name: "other",
			source: "extension",
			sourceInfo: { path: file, source: "file" },
		},
	]);
	for (const [event, mode] of [
		[{ ...baseEvent, text: "/unknown" }, "tui"],
		[{ ...baseEvent, source: "extension" }, "tui"],
		[baseEvent, "rpc"],
		[{ ...baseEvent, text: "/other" }, "tui"],
		[baseEvent, "tui"],
	]) {
		assert.deepEqual(await h.invoke(event, mode), { action: "continue" });
	}
	assert.equal(h.sent.length, 0);
	assert.equal(h.entries.length, 0);
});

test("uses the first duplicate prompt path in reported order", async () => {
	const first = await template("first");
	const second = await template("second");
	const h = harness([prompt("task", first), prompt("task", second)]);
	assert.deepEqual(await h.invoke(baseEvent), { action: "handled" });
	assert.equal((await h.before("/task")).message.content, "first");
});

test("notifies and handles file read failures", async () => {
	const h = harness([prompt("task", "/missing/prompt.md")]);
	assert.deepEqual(await h.invoke(baseEvent), { action: "handled" });
	assert.equal(h.sent.length, 0);
	assert.equal(h.sentUsers.length, 0);
	assert.deepEqual(h.entries[0].data, { command: "/task" });
	assert.equal(h.notifications[0][1], "error");
});

test("entry renderer shows only the original invocation", () => {
	const h = harness();
	const component = h.renderer(
		{ data: { command: "/task original" } },
		{},
		{ bg: (_name, text) => text, fg: (_name, text) => text },
	);
	const rendered = component.render(80).join("\n");
	assert.ok(rendered.includes("/task original"));
	assert.ok(!rendered.includes("Expanded request"));
});
