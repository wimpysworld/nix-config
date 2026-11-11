// Gate: checks.x86_64-linux.pi-extension-delivery, run by just check and CI.
import assert from "node:assert/strict";
import { realpathSync } from "node:fs";
import { homedir } from "node:os";
import { join, resolve, dirname } from "node:path";
import { pathToFileURL } from "node:url";

const { loadExtensions } = await import(pathToFileURL(process.argv[2]).href);
const paths = ["provider-router", "prompt-template-display"].map((name) =>
	join(homedir(), ".pi/agent/extensions", name, "index.ts"),
);
assert.equal(
	realpathSync(resolve(dirname(realpathSync(paths[1])), "../provider-router/index.ts")),
	realpathSync(paths[0]),
);
const { extensions, errors } = await loadExtensions(paths, homedir());
assert.deepEqual(errors, []);
assert.equal(extensions.length, paths.length);
assert.ok(extensions[0].handlers.has("tool_call"));
assert.ok(extensions[1].handlers.has("input"));
