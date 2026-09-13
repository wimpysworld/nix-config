import { readFile } from "node:fs/promises";
import { stripTypeScriptTypes } from "node:module";
import { fileURLToPath, pathToFileURL } from "node:url";
import { join } from "node:path";

const sdkStub = `
export function isToolCallEventType(name, event) {
  return event.toolName === name;
}
`;

export async function resolve(specifier, context, nextResolve) {
	if (context.parentURL?.includes("/node_modules/")) {
		try {
			return await nextResolve(specifier, context);
		} catch (error) {
			if (
				error.code === "ERR_MODULE_NOT_FOUND" &&
				specifier === "@earendil-works/pi-coding-agent" &&
				process.env.PI_CODING_AGENT_DIR
			) {
				return nextResolve(
					pathToFileURL(join(process.env.PI_CODING_AGENT_DIR, "dist/index.js")).href,
					context,
				);
			}
			if (error.code !== "ERR_MODULE_NOT_FOUND" || !specifier.endsWith(".js"))
				throw error;
			return nextResolve(specifier.slice(0, -3) + ".ts", context);
		}
	}
	if (specifier === "@earendil-works/pi-ai/compat") {
		return {
			shortCircuit: true,
			url: `data:text/javascript,${encodeURIComponent('export function getSupportedThinkingLevels(model) { return model.supportedThinking ?? ["off", "minimal", "low", "medium", "high", "xhigh"]; }')}`,
		};
	}
	if (specifier === "@earendil-works/pi-coding-agent") {
		return {
			shortCircuit: true,
			url: `data:text/javascript,${encodeURIComponent(sdkStub)}`,
		};
	}
	return nextResolve(specifier, context);
}

export async function load(url, context, nextLoad) {
	if (url.startsWith("file:") && url.endsWith(".ts")) {
		return {
			shortCircuit: true,
			format: "module",
			source: stripTypeScriptTypes(await readFile(fileURLToPath(url), "utf8"), {
				mode: "transform",
			}),
		};
	}
	return nextLoad(url, context);
}
