import { readFileSync } from "node:fs";
import { spawnSync } from "node:child_process";

const scannerPath = "@tripwireScanner@";
const rulesPath = "@tripwireRules@";
const correctionPromptPath = "@tripwireCorrectionPrompt@";
const FALLBACK_BLOCK = "Blocked. Revise this prose to follow the Communication Rules.";
const skippedFinishes = new Set(["tool-calls", "error", "unknown"]);

function readText(file: string): string {
  return readFileSync(file, "utf8").trimEnd();
}

function decide(event: string, payload: unknown) {
  try {
    const result = spawnSync(scannerPath, ["opencode", event], {
      input: JSON.stringify(payload), encoding: "utf8",
    });
    if (result.status === 0) {
      const decision = JSON.parse(result.stdout);
      if (decision && typeof decision === "object" && typeof decision.decision === "string") return decision;
    }
  } catch {
    // A scanner failure must not authorise a side effect.
  }
  throw new Error(FALLBACK_BLOCK);
}

function reminder() {
  const result = spawnSync(scannerPath, ["remind-brief", "opencode"], { encoding: "utf8" });
  return (result.status === 0 && result.stdout.trim()) || `Communication Rules:\n${readText(rulesPath)}`;
}

// V2 plugin client methods resolve to the bare value. Older clients wrapped it
// as `{ data }`, so accept both forms.
function unwrap(result: any) {
  return result && typeof result === "object" && !Array.isArray(result) && "data" in result ? result.data : result;
}

function logError(message: string, error: unknown) {
  console.error(`Communication Rules: ${message}`, error);
}

export default {
  id: "nix-config.communication-rules",
  async setup(ctx: any) {
    const controller = new AbortController();
    const notify = async (sessionID: string, text: string) => {
      if (text) await ctx.session.synthetic({
        sessionID, text, description: "Communication Rules", resume: false,
      });
    };
    const inject = (event: any, sections: string[]) => {
      for (const text of sections) {
        if (text && !event.system.some((part: any) => part.type === "text" && part.text === text)) {
          event.system.push({ type: "text", text });
        }
      }
    };
    // In V2 a session hook that throws fails the model request and the session
    // drain, so a session hook logs its error and lets the turn continue.
    const guard = (name: string, callback: (event: any) => void) => (event: any) => {
      try {
        callback(event);
      } catch (error) {
        logError(`${name} hook failed.`, error);
        try { inject(event, [reminder()]); } catch { /* The turn continues without the rules. */ }
      }
    };
    await ctx.session.hook("context", guard("context", (event: any) => {
      const decision = decide("context", { sessionID: event.sessionID });
      if (decision.decision !== "pass") throw new Error(`Unexpected context decision: ${decision.decision}`);
      inject(event, [
        ...(decision.inject_base_rules ? [reminder()] : []),
        ...(decision.append_correction ? [readText(correctionPromptPath)] : []),
      ]);
    }));
    for (const name of ["compaction", "generate", "title"]) {
      await ctx.session.hook(name, guard(name, (event: any) => inject(event, [reminder()])));
    }
    // A rejection here fails only the one tool call, so blocks still reject.
    await ctx.tool.hook("execute.before", async (event: any) => {
      const tools = unwrap(await ctx.tool.list());
      const tool = Array.isArray(tools) ? tools.find((item: any) => item.id === event.tool) : undefined;
      const name = tool?.options?.namespace
        ? `mcp__${tool.options.namespace}__${tool.name}` : event.tool;
      const decision = decide("tool.execute.before", {
        event: "tool.execute.before", sessionID: event.sessionID, tool: name, args: event.input,
      });
      if (decision.decision === "pass") return;
      if (decision.decision === "yield" || decision.decision === "allow-revise") {
        await notify(event.sessionID, decision.notice);
        return;
      }
      throw new Error(decision.notice || decision.block_message || FALLBACK_BLOCK);
    });
    const check = async (event: any) => {
      const session = unwrap(await ctx.session.get({ sessionID: event.data.sessionID }));
      if (session?.location?.directory !== ctx.location.directory) return;
      const messages = unwrap(await ctx.session.context({ sessionID: session.id }));
      const message = Array.isArray(messages)
        ? messages.find((item: any) => item.id === event.data.assistantMessageID) : undefined;
      if (message?.type !== "assistant") throw new Error("Completed message is unavailable.");
      const text = message.content.filter((part: any) => part.type === "text")
        .map((part: any) => part.text).join("\n");
      // The scanner treats empty content as a breach, so skip steps with no text.
      if (!text.trim()) return;
      const decision = decide("message.final", {
        event: "message.final", surface: "final", sessionID: session.id, message: { content: text },
      });
      if (!["pass", "block"].includes(decision.decision)) throw new Error(`Unexpected final decision: ${decision.decision}`);
      await notify(session.id, decision.notice);
    };
    const observe = async () => {
      for await (const event of ctx.event.subscribe({ signal: controller.signal })) {
        // Tool-call, error and unknown steps carry no final prose. A provider
        // error must surface as an error, not as a rules breach.
        if (event?.type !== "session.step.ended" || skippedFinishes.has(event.data?.finish)) continue;
        // One failed check must not stop the checks of later turns.
        try {
          await check(event);
        } catch (error) {
          logError("final-message check failed.", error);
        }
      }
      if (!controller.signal.aborted) throw new Error("event stream closed.");
    };
    const observing = observe().catch((error) => {
      if (!controller.signal.aborted) logError("event observation stopped.", error);
    });
    return async () => { controller.abort(); await observing; };
  },
};
