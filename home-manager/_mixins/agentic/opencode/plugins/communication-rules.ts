import { spawnSync } from "node:child_process";

const scannerPath = "@tripwireScanner@";
const skippedFinishes = new Set(["tool-calls", "error", "unknown"]);

function decide(event: string, payload: unknown) {
  const result = spawnSync(scannerPath, ["opencode", event], {
    input: JSON.stringify(payload), encoding: "utf8", timeout: 2000, maxBuffer: 64 * 1024,
  });
  if (!result.error && result.status === 0) {
    const decision = JSON.parse(result.stdout);
    if (decision && ["pass", "advisory"].includes(decision.decision)
      && (decision.notice === undefined || typeof decision.notice === "string")) return decision;
  }
  throw new Error("Communication Rules checker unavailable.");
}

// V2 plugin client methods resolve to the bare value. Older clients wrapped it
// as `{ data }`, so accept both forms.
function unwrap(result: any) {
  return result && typeof result === "object" && !Array.isArray(result) && "data" in result ? result.data : result;
}

export default {
  id: "nix-config.communication-rules",
  async setup(ctx: any) {
    const controller = new AbortController();
    const noticed = new Set<string>();
    const diagnosed = new Set<string>();
    const diagnose = (sessionID: string) => {
      if (diagnosed.has(sessionID)) return;
      diagnosed.add(sessionID);
      console.error("Communication Rules: checker unavailable. The operation is unchanged.");
    };
    const notify = async (sessionID: string, text: string) => {
      if (!text || noticed.has(sessionID)) return;
      noticed.add(sessionID);
      await ctx.session.synthetic({
        sessionID, text: text.slice(0, 320), description: "Communication Rules", resume: false,
      });
    };
    const inject = (event: any, sections: string[]) => {
      for (const text of sections) {
        if (text && !event.system.some((part: any) => part.type === "text" && part.text === text)) {
          event.system.push({ type: "text", text });
        }
      }
    };
    const guard = (callback: (event: any) => void) => (event: any) => {
      try {
        callback(event);
      } catch {
        diagnose(event.sessionID);
      }
    };
    await ctx.session.hook("prompt", guard((event: any) => {
      noticed.delete(event.sessionID);
      diagnosed.delete(event.sessionID);
      decide("turn-start", { sessionID: event.sessionID, turn_id: event.messageID });
    }));
    await ctx.session.hook("context", guard((event: any) => {
      const decision = decide("context", { sessionID: event.sessionID });
      if (decision.notice) {
        inject(event, [decision.notice.slice(0, 320)]);
        noticed.add(event.sessionID);
      }
    }));
    await ctx.tool.hook("execute.before", async (event: any) => {
      try {
        const tools = unwrap(await ctx.tool.list());
        const tool = Array.isArray(tools) ? tools.find((item: any) => item.id === event.tool) : undefined;
        const name = tool?.options?.namespace
          ? `mcp__${tool.options.namespace}__${tool.name}` : event.tool;
        const decision = decide("tool.execute.before", {
          event: "tool.execute.before", sessionID: event.sessionID, tool: name, args: event.input,
        });
        await notify(event.sessionID, decision.notice);
      } catch {
        diagnose(event.sessionID);
      }
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
      if (!text.trim()) return;
      const decision = decide("message.final", {
        event: "message.final", surface: "final", sessionID: session.id, message: { role: "assistant", content: text },
      });
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
        } catch {
          diagnose(event.data.sessionID);
        }
      }
      if (!controller.signal.aborted) throw new Error("event stream closed.");
    };
    const observing = observe().catch(() => {
      if (!controller.signal.aborted) diagnose("event-stream");
    });
    return async () => { controller.abort(); await observing; };
  },
};
