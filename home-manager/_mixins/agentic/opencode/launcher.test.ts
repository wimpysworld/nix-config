// Gate: the OpenCode launcher build runs this suite in postCheck.
import { test } from "bun:test";
import assert from "node:assert/strict";
import { mkdtempSync, mkdirSync, readFileSync, writeFileSync, symlinkSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { spawnSync } from "node:child_process";

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
