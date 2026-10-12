// Copies the runtime dependency closure of the named packages from
// `node_modules` into `<out>/node_modules`. Vite bundles every front-end
// package into `dist/`, so the server needs only the packages that it imports.
// Usage: bun prune-node-modules.ts <out> <package>...
import { cpSync, existsSync, readFileSync } from "node:fs";
import { dirname, join, relative, resolve } from "node:path";

const [out, ...roots] = process.argv.slice(2);
const top = resolve("node_modules");
const seen = new Set<string>();

// Node resolution: the nearest `node_modules/<name>` from `from` upwards.
function find(name: string, from: string): string | null {
  for (let dir = from; dir.startsWith(top); dir = dirname(dir)) {
    const candidate = join(dir, "node_modules", name);
    if (existsSync(join(candidate, "package.json"))) return candidate;
    if (dir === top) break;
  }
  const hoisted = join(top, name);
  return existsSync(join(hoisted, "package.json")) ? hoisted : null;
}

function visit(name: string, from: string, optional: boolean) {
  const dir = find(name, from);
  if (!dir) {
    if (optional) return;
    throw new Error(`missing runtime dependency ${name}`);
  }
  if (seen.has(dir)) return;
  seen.add(dir);
  cpSync(dir, join(out, "node_modules", relative(top, dir)), { recursive: true, verbatimSymlinks: true });
  const manifest = JSON.parse(readFileSync(join(dir, "package.json"), "utf8"));
  for (const dep of Object.keys(manifest.dependencies ?? {})) visit(dep, dir, false);
  for (const dep of Object.keys(manifest.optionalDependencies ?? {})) visit(dep, dir, true);
}

for (const root of roots) visit(root, top, false);
