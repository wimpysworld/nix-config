// Gate: the OpenCode launcher build runs this suite in postCheck.
import { test } from "bun:test";
import assert from "node:assert/strict";
import { mkdtempSync, mkdirSync, readFileSync, writeFileSync, symlinkSync, lstatSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, dirname } from "node:path";
import { spawn, spawnSync } from "node:child_process";
import { createInterface } from "node:readline";
import { once } from "node:events";

const root = mkdtempSync(join(tmpdir(), "opencode-launcher-test-"));
const trusted = join(root, "trusted");
const untrusted = join(root, "untrusted");
mkdirSync(trusted); mkdirSync(untrusted);
symlinkSync(untrusted, join(trusted, "outside"));
const target = join(root, "target");
writeFileSync(target, `#!${Bun.which("python3")}
import json, os, sys
print(json.dumps({"args": sys.argv[1:], "projectDisabled": os.getenv("OPENCODE_DISABLE_PROJECT_CONFIG"), "modelsDisabled": os.getenv("OPENCODE_DISABLE_MODELS_FETCH"), "fenced": os.getenv("FENCE_SANDBOX")}))
`, { mode: 0o755 });
const script = join(root, "launcher");
writeFileSync(script, "set -euo pipefail\n" + readFileSync(new URL("./launcher.sh", import.meta.url), "utf8")
  .replaceAll("@trustedRoots@", `'${trusted}' | '${trusted}'/*`).replaceAll("@opencode@", `'${target}'`));
function launch(args: string[], fenced = false, cwd = trusted) {
  const result = spawnSync("bash", [script, ...args], {
    cwd, encoding: "utf8", env: { PATH: process.env.PATH, HOME: root, FENCE_SANDBOX: fenced ? "1" : "0" },
  });
  return { ...result, data: result.status === 0 ? JSON.parse(result.stdout) : undefined };
}
test("interactive launches resume on private servers", () => {
  assert.deepEqual(launch([]).data.args, ["--standalone", "--continue"]);
  assert.deepEqual(launch(["mini"]).data.args, ["mini", "--standalone", "--continue"]);
  assert.deepEqual(launch(["--standalone"]).data.args, ["--continue", "--standalone"]);
  assert.deepEqual(launch(["mini", "--standalone=true"]).data.args, ["mini", "--continue", "--standalone=true"]);
  for (const session of [["--session", "session"], ["--session=session"], ["-s", "session"], ["--continue"], ["--no-continue"]]) {
    assert.deepEqual(launch(session).data.args, ["--standalone", ...session]);
  }
});
test("management and automation commands never receive resume flags", () => {
  for (const command of ["run", "models", "stats", "api", "reload"]) {
    assert.deepEqual(launch(["--print-logs", command]).data.args, ["--print-logs", command, "--standalone"]);
  }
  for (const args of [["acp"], ["acp", "--login"], ["service", "status"], ["pair"], ["update"], ["--help"], ["--version"], ["plugin", "list"]]) {
    assert.deepEqual(launch(args).data.args, args);
  }
});
test("nested commands receive server flags after the leaf", () => {
  for (const [group, leaves] of [
    ["auth", ["list", "login", "logout", "export", "import", "switch"]],
    ["session", ["list", "delete", "export", "import"]],
  ] as const) {
    for (const leaf of leaves) {
      const args = ["--print-logs", group, leaf];
      assert.deepEqual(launch(args, true).data.args, [...args, "--standalone"]);
    }
    assert.deepEqual(launch([group]).data.args, [group]);
  }
  assert.deepEqual(launch(["auth", "--print-logs", "list", "--format", "json"]).data.args,
    ["auth", "--print-logs", "list", "--standalone", "--format", "json"]);
  assert.deepEqual(launch(["session", "export", "session-id"]).data.args,
    ["session", "export", "--standalone", "session-id"]);
  assert.deepEqual(launch(["--standalone", "auth", "list"], true).data.args,
    ["--standalone", "auth", "list", "--standalone"]);
  assert.deepEqual(launch(["auth", "list", "--standalone"], true).data.args,
    ["auth", "list", "--standalone"]);
});
test("option values and literal arguments cannot change command detection", () => {
  assert.deepEqual(launch(["--prompt", "run", "mini"]).data.args,
    ["--prompt", "run", "mini", "--standalone", "--continue"]);
  for (const flag of ["--data", "-d", "--header", "-H", "--param"]) {
    const args = ["api", "post", "/test", flag, "--server"];
    assert.deepEqual(launch(args, true).data.args, ["api", "--standalone", ...args.slice(1)]);
  }
  assert.deepEqual(launch(["run", "--", "--help", "--server"], true).data.args,
    ["run", "--standalone", "--", "--help", "--server"]);
  mkdirSync(join(trusted, "run"), { recursive: true });
  assert.deepEqual(launch(["--", "run"]).data.args, ["--standalone", "--continue", "--", "run"]);
  assert.deepEqual(launch(["auth", "list", "--help"]).data.args, ["auth", "list", "--help"]);
});
test("Fence rejects external servers and unsupported shared-service operations", () => {
  for (const args of [["--server", "http://localhost:4096"], ["run", "--server=http://localhost:4096"], ["service", "start"], ["serve"], ["pair"], ["mcp", "list"], ["plugin", "list"], ["--standalone=false"], ["--standalone", "false"], ["--standalone=0"], ["--no-standalone"]]) {
    assert.equal(launch(args, true).status, 2, JSON.stringify(args));
  }
  for (const args of [["auth", "list", "--server", "http://localhost:4096"], ["session", "export", "--server=http://localhost:4096"], ["auth", "unknown"], ["session", "unknown"]]) {
    assert.equal(launch(args, true).status, 2, JSON.stringify(args));
  }
  for (const args of [[], ["run"], ["mini"], ["api"], ["acp"]]) assert.equal(launch(args, true).status, 0);
  assert.deepEqual(launch(["run", "--server", "http://localhost:4096"]).data.args, ["run", "--server", "http://localhost:4096"]);
});
test("trust follows the canonical selected directory, not the launch directory", () => {
  assert.equal(launch([]).data.projectDisabled, null);
  assert.equal(launch([untrusted]).data.projectDisabled, "1");
  assert.equal(launch([join(trusted, "outside")]).data.projectDisabled, "1");
  assert.equal(launch([], false, untrusted).data.projectDisabled, "1");
  assert.equal(launch(["session", "import", "session.json", "--directory", untrusted]).data.projectDisabled, "1");
  assert.equal(launch(["session", "import", "session.json", `--directory=${untrusted}`]).data.projectDisabled, "1");
  assert.notEqual(launch([join(root, "missing")]).status, 0);
  assert.equal(launch([]).data.modelsDisabled, "1");
});

for (const layout of ["plain", "fenced", "escaping-entrypoint"]) {
  test.skipIf(!process.env.OPENCODE_TEST_DELIVERY)(`generated plugin discovery and permissions: ${layout}`, async () => {
    const delivery = JSON.parse(readFileSync(process.env.OPENCODE_TEST_DELIVERY!, "utf8"));
    const home = mkdtempSync(join(tmpdir(), "opencode-discovery-test-"));
    const configHome = join(home, ".config");
    const configDir = join(configHome, "opencode");
    const project = join(home, "project");
    mkdirSync(project);
    const expected: string[] = [];
    for (const file of delivery.files) {
      const target = join(home, file.target);
      mkdirSync(dirname(target), { recursive: true });
      if (file.target.includes("/plugins/")) {
        assert.equal(file.recursive, false, "Home Manager must link the whole plugin directory");
        assert.ok(lstatSync(file.source).isDirectory());
        assert.ok(lstatSync(join(file.source, "index.ts")).isFile(), "The entrypoint must be a regular file");
        expected.push(`nix-config.${file.target.split("/").at(-1)}`);
        if (layout === "escaping-entrypoint") {
          mkdirSync(target);
          symlinkSync(join(file.source, "index.ts"), join(target, "index.ts"));
          continue;
        }
      }
      symlinkSync(file.source, target);
    }
    assert.ok(expected.includes("nix-config.provider-router"));
    writeFileSync(join(configDir, "opencode.json"), JSON.stringify({
      update: "disable", share: "disabled", websearch: false,
      permissions: delivery.permissions,
    }));
    const child = spawn(process.env.OPENCODE_TEST_BINARY!, ["--print-logs", "serve", "--hostname", "127.0.0.1", "--port", "0"], {
      cwd: project,
      env: {
        PATH: process.env.PATH, HOME: home,
        XDG_CONFIG_HOME: configHome, XDG_DATA_HOME: join(home, ".local/share"),
        OPENCODE_CONFIG_DIR: configDir,
        XDG_STATE_HOME: join(home, ".local/state"), XDG_CACHE_HOME: join(home, ".cache"),
        OPENCODE_DISABLE_MODELS_FETCH: "1", OPENCODE_DISABLE_PROJECT_CONFIG: "1",
        OPENCODE_SERVER_PASSWORD: "discovery-test-only",
        FENCE_SANDBOX: layout === "plain" ? "0" : "1",
      },
      stdio: ["ignore", "pipe", "pipe"],
    });
    const exited = once(child, "exit");
    let logs = "";
    child.stderr.on("data", (chunk: Uint8Array) => { logs += chunk; });
    const lines = createInterface({ input: child.stdout });
    try {
      const base = await new Promise<string>((resolve, reject) => {
        const timer = setTimeout(() => reject(new Error(`Server startup timed out: ${logs}`)), 30000);
        child.once("error", (error: Error) => { clearTimeout(timer); reject(error); });
        child.once("exit", () => { clearTimeout(timer); reject(new Error(`Server exited: ${logs}`)); });
        lines.on("line", (line: string) => {
          logs += line + "\n";
          const match = line.match(/server listening on (http:\/\/127\.0\.0\.1:\d+)/);
          if (match) { clearTimeout(timer); resolve(match[1]); }
        });
      });
      async function api(path: string, body?: unknown) {
        const response = await fetch(base + path, {
          method: body === undefined ? "GET" : "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Basic ${btoa("opencode:discovery-test-only")}`,
          },
          body: body === undefined ? undefined : JSON.stringify(body),
          signal: AbortSignal.timeout(10000),
        });
        const text = await response.text();
        assert.ok(response.ok, `${path}: ${response.status} ${text}`);
        return JSON.parse(text).data;
      }
      // The local catalogue endpoint waits for plugin activation without inference or downloads.
      await api("/api/model");
      const plugins = await api("/api/plugin");
      for (const id of expected) {
        const plugin = plugins.find((entry: any) => entry.id === id);
        if (layout === "escaping-entrypoint") assert.equal(plugin, undefined);
        else assert.equal(plugin?.state.status, "active", `${id}: ${JSON.stringify(plugin)}\n${logs}`);
      }
      const session = await api("/api/session", { agent: "donatello", location: { directory: project } });
      async function permission(action: string, resource = "*") {
        return (await api(`/api/session/${session.id}/permission`, { action, resources: [resource] })).effect;
      }
      assert.equal(await permission("external_directory", "/outside/project"), layout === "fenced" ? "allow" : "ask");
      for (const action of ["webfetch", "websearch", "subagent"]) assert.equal(await permission(action), "deny", action);
      assert.equal(await permission("question"), "allow");
      const pending = await api(`/api/session/${session.id}/permission`);
      assert.equal(pending.length, layout === "fenced" ? 0 : 1);
      // Session denies also cover hosts that do not install the Slack integration.
      const denied = await api("/api/session", {
        agent: "donatello", location: { directory: project },
        permissions: [{ action: "slack_slack_send_message", resource: "*", effect: "deny" }],
      });
      assert.equal((await api(`/api/session/${denied.id}/permission`, {
        action: "slack_slack_send_message", resources: ["channel"],
      })).effect, "deny");
      for (const rule of delivery.permissions.filter((rule: any) => rule.effect === "deny" && rule.action.startsWith("slack_"))) {
        assert.equal(await permission(rule.action), "deny", rule.action);
      }
    } finally {
      lines.close();
      child.kill("SIGTERM");
      await exited;
    }
  }, 60000);
}
