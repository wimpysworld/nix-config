import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { Editor } from "@earendil-works/pi-tui";
import { readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

// Hide Pi's software cursor so the terminal emulator draws the only cursor.
// The pi-tui editor always paints an inverse-video block at the cursor cell,
// and `showHardwareCursor = true` only un-hides the terminal cursor on top of
// it, which shows two cursors. This extension patches the shared Editor
// render so the inverse code after the zero-width cursor marker is removed,
// which leaves the marker (the TUI positions the hardware cursor from it)
// and hides the block.
//
// Safety: the patch runs only when the hardware cursor is enabled in Pi's
// settings, so `showHardwareCursor = false` makes this extension inert and
// restores stock behaviour. When a Pi update changes the marker or the
// escape codes, the strip finds no match and returns each line unchanged,
// so the worst case is the stock double cursor, never a broken editor.
declare const process: {
	env: Record<string, string | undefined>;
};

const CURSOR_MARKER = "\u001b_pi:c\u0007";
const INVERSE_CODE = "\u001b[7m";
const PATCHED_FLAG = Symbol.for("noughty.hardware-cursor.patched");

function hardwareCursorEnabled(): boolean {
	const agentDir = process.env.PI_CODING_AGENT_DIR ?? join(homedir(), ".pi", "agent");
	try {
		const settings = JSON.parse(readFileSync(join(agentDir, "settings.json"), "utf-8"));
		if (typeof settings.showHardwareCursor === "boolean") {
			return settings.showHardwareCursor;
		}
	} catch {
		// No readable settings file: fall through to the environment default.
	}
	return process.env.PI_HARDWARE_CURSOR === "1";
}

function stripSoftwareCursor(line: string): string {
	const markerIndex = line.indexOf(CURSOR_MARKER);
	if (markerIndex === -1) return line;
	const cursorStart = markerIndex + CURSOR_MARKER.length;
	if (!line.startsWith(INVERSE_CODE, cursorStart)) return line;
	return line.slice(0, cursorStart) + line.slice(cursorStart + INVERSE_CODE.length);
}

export default function registerHardwareCursor(_pi: ExtensionAPI): void {
	if (!hardwareCursorEnabled()) return;

	const prototype = Editor.prototype as {
		render(width: number): string[];
		[PATCHED_FLAG]?: boolean;
	};
	if (prototype[PATCHED_FLAG]) return;
	prototype[PATCHED_FLAG] = true;

	const originalRender = prototype.render;
	prototype.render = function (width: number): string[] {
		const lines = originalRender.call(this, width);
		if (!Array.isArray(lines)) return lines;
		return lines.map((line) => (typeof line === "string" ? stripSoftwareCursor(line) : line));
	};
}
