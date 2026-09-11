import { readFile } from "node:fs/promises";
import { stripTypeScriptTypes } from "node:module";

const sdkStub = `
export function isToolCallEventType(name, event) {
  return event.toolName === name;
}
`;

export async function resolve(specifier, context, nextResolve) {
	if (context.parentURL?.includes("/node_modules/"))
		return nextResolve(specifier, context);
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
			source: stripTypeScriptTypes(await readFile(new URL(url), "utf8")),
		};
	}
	return nextLoad(url, context);
}
