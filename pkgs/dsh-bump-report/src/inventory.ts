// Reads upstream workspace trees and bundle outputs into plain data.

import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { parse } from "yaml";

const SKIP_DIRS = new Set([
  "node_modules",
  ".git",
  ".pnpm",
  "dist",
  "coverage",
  ".turbo",
]);
const TEXT_EXT = /\.(?:ya?ml|json|m?js|cjs|tsx?|nix|patch|sh)$/;
const REF_RE = /@deepseek-ai\/[a-z0-9][a-z0-9-]*(?:\/[A-Za-z0-9._@-]+)*/g;

export interface Manifest {
  name?: string;
  version?: string;
  private?: boolean;
  exports?: unknown;
  bin?: unknown;
  gypfile?: boolean;
  scripts?: Record<string, string>;
  engines?: Record<string, string>;
  dsh?: { bundle?: { patch?: unknown } };
}

export interface WorkspacePackage {
  name: string;
  version: string | undefined;
  dir: string;
  private: boolean;
  exports: string[] | null;
  bin: unknown;
  bundle: { patch?: unknown } | null;
  lifecycle: Record<string, string>;
  native: boolean;
}

export interface Workspace {
  packages?: string[];
  [key: string]: unknown;
}

export interface Inventory {
  workspace: Workspace;
  packages: Map<string, WorkspacePackage>;
}

export type Rows = Map<string, { names: Set<string>; files: Set<string> }>;

export interface Row {
  id: unknown;
  name: string | null;
}

// One bundle as `nix eval` lists it.
export interface BundleEntry {
  attr: string;
  version: string;
  out: string;
  src: string | null;
  srcDrv: string | null;
  overrideDshEngineVersion: boolean;
  workspace: boolean;
}

export type BundleSource = "built" | "source" | "unavailable";

export function readJson<T = unknown>(file: string): T {
  return JSON.parse(fs.readFileSync(file, "utf8"));
}

// dsh patches mark expressions with !!js; the report only needs their text.
const jsTag = {
  tag: "tag:yaml.org,2002:js",
  resolve: (source: string) => source,
};

function readYaml<T = unknown>(file: string): T {
  return parse(fs.readFileSync(file, "utf8"), { customTags: [jsTag] }) as T;
}

// Every mapping in a YAML value, the value itself first.
function* mappings(value: unknown): Generator<Record<string, unknown>> {
  if (Array.isArray(value)) {
    for (const item of value) yield* mappings(item);
  } else if (value !== null && typeof value === "object") {
    yield value as Record<string, unknown>;
    for (const item of Object.values(value)) yield* mappings(item);
  }
}

export function sha(file: string): string {
  return crypto
    .createHash("sha256")
    .update(fs.readFileSync(file))
    .digest("hex");
}

export function* walk(
  root: string,
  { maxDepth = Infinity, depth = 0 } = {},
): Generator<string> {
  let entries: fs.Dirent[];
  try {
    entries = fs.readdirSync(root, { withFileTypes: true });
  } catch {
    return;
  }
  for (const entry of entries) {
    if (SKIP_DIRS.has(entry.name)) continue;
    const full = path.join(root, entry.name);
    if (entry.isDirectory()) {
      if (depth < maxDepth) yield* walk(full, { maxDepth, depth: depth + 1 });
    } else if (entry.isFile()) {
      yield full;
    }
  }
}

function matchGlob(root: string, pattern: string): string[] {
  let dirs = [root];
  for (const segment of pattern.split("/")) {
    const next: string[] = [];
    for (const dir of dirs) {
      if (segment === "*") {
        for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
          if (entry.isDirectory() && !SKIP_DIRS.has(entry.name))
            next.push(path.join(dir, entry.name));
        }
      } else if (fs.existsSync(path.join(dir, segment))) {
        next.push(path.join(dir, segment));
      }
    }
    dirs = next;
  }
  return dirs;
}

// The pnpm workspace file and every named package it includes.
export function inventory(root: string): Inventory {
  const workspace = readYaml<Workspace>(path.join(root, "pnpm-workspace.yaml"));
  const packages = new Map<string, WorkspacePackage>();
  for (const pattern of workspace.packages ?? []) {
    if (pattern.startsWith("!")) continue;
    for (const dir of matchGlob(root, pattern)) {
      const manifestPath = path.join(dir, "package.json");
      if (!fs.existsSync(manifestPath)) continue;
      const manifest = readJson<Manifest>(manifestPath);
      if (typeof manifest.name !== "string") continue;
      const exportsField = manifest.exports;
      packages.set(manifest.name, {
        name: manifest.name,
        version: manifest.version,
        dir: path.relative(root, dir),
        private: manifest.private === true,
        exports:
          exportsField &&
          typeof exportsField === "object" &&
          !Array.isArray(exportsField) &&
          Object.keys(exportsField).some((key) => key.startsWith("."))
            ? Object.keys(exportsField)
            : null,
        bin: manifest.bin ?? null,
        bundle: manifest.dsh?.bundle ?? null,
        lifecycle: Object.fromEntries(
          ["preinstall", "install", "postinstall"]
            .filter((key) => manifest.scripts?.[key])
            .map((key) => [key, manifest.scripts?.[key] ?? ""]),
        ),
        native:
          manifest.gypfile === true ||
          fs.existsSync(path.join(dir, "binding.gyp")) ||
          fs.existsSync(path.join(dir, "Cargo.toml")),
      });
    }
  }
  return { workspace, packages };
}

export function exportAllows(
  exportKeys: string[] | null,
  subpath: string,
): boolean {
  if (exportKeys === null) return true;
  for (const key of exportKeys) {
    if (key === subpath) return true;
    const star = key.indexOf("*");
    if (star === -1) continue;
    const prefix = key.slice(0, star);
    const suffix = key.slice(star + 1);
    if (
      subpath.length >= prefix.length + suffix.length &&
      subpath.startsWith(prefix) &&
      subpath.endsWith(suffix)
    )
      return true;
  }
  return false;
}

// "ok" when the package exists and exports the subpath.
export function refStatus(
  inv: Inventory,
  ref: string,
): "ok" | "missing-package" | "unexported" {
  const [scope, name, ...rest] = ref.split("/");
  const pkg = inv.packages.get(`${scope}/${name}`);
  if (!pkg) return "missing-package";
  if (rest.length === 0) return "ok";
  return exportAllows(pkg.exports, `./${rest.join("/")}`) ? "ok" : "unexported";
}

function bundlePatchFiles(root: string, pkg: WorkspacePackage): string[] {
  if (!pkg.bundle) return [];
  const declared = Array.isArray(pkg.bundle.patch)
    ? pkg.bundle.patch
    : [pkg.bundle.patch];
  const files = declared
    .filter((file): file is string => typeof file === "string")
    .map((file) => path.join(root, pkg.dir, file));
  const presets = path.join(root, pkg.dir, "presets");
  if (fs.existsSync(presets)) {
    for (const entry of fs.readdirSync(presets)) {
      if (entry.endsWith(".yml")) files.push(path.join(presets, entry));
    }
  }
  return files.filter((file) => fs.existsSync(file));
}

// The mappings with an `id` anywhere in a YAML file; none when it does not parse.
export function rowsOf(file: string): Row[] {
  let document: unknown;
  try {
    document = readYaml(file);
  } catch {
    return [];
  }
  const rows: Row[] = [];
  for (const map of mappings(document)) {
    if (!("id" in map)) continue;
    const name = map.name;
    rows.push({
      id: map.id,
      name:
        name === null || name === undefined || name === false
          ? null
          : String(name),
    });
  }
  return rows;
}

// Row ids declared by the workspace bundles, with their names and files.
export function upstreamRows(root: string, inv: Inventory): Rows {
  const rows: Rows = new Map();
  for (const pkg of inv.packages.values()) {
    for (const file of bundlePatchFiles(root, pkg)) {
      const relative = path.relative(root, file);
      for (const row of rowsOf(file)) {
        if (typeof row.id !== "string") continue;
        const entry = rows.get(row.id) ?? {
          names: new Set(),
          files: new Set(),
        };
        if (row.name) entry.names.add(row.name);
        entry.files.add(relative);
        rows.set(row.id, entry);
      }
    }
  }
  return rows;
}

// The package names in each `export const` list of the file that declares
// OPTIONAL_BUNDLES.
export function officialLists(root: string): {
  file: string | null;
  lists: Record<string, string[]>;
} {
  for (const file of walk(path.join(root, "packages"), { maxDepth: 4 })) {
    if (!file.endsWith(".ts")) continue;
    const text = fs.readFileSync(file, "utf8");
    if (!text.includes("export const OPTIONAL_BUNDLES")) continue;
    const lists: Record<string, string[]> = {};
    const blocks = text.split(/^export const /m).slice(1);
    for (const block of blocks) {
      const name = block.match(/^([A-Z_]+)/)?.[1];
      if (!name) continue;
      lists[name] = [
        ...new Set(block.match(/@deepseek-ai\/[a-z0-9-]+/g) ?? []),
      ].sort();
    }
    return { file: path.relative(root, file), lists };
  }
  return { file: null, lists: {} };
}

// The first file that mentions each @deepseek-ai reference.
export function scanRefs(files: Iterable<string>): Map<string, string> {
  const refs = new Map<string, string>();
  for (const file of files) {
    if (!TEXT_EXT.test(file) || file.endsWith(".d.ts")) continue;
    let text;
    try {
      if (fs.statSync(file).size > 4 * 1024 * 1024) continue;
      text = fs.readFileSync(file, "utf8");
    } catch {
      continue;
    }
    // Removed lines of a patch are not references.
    if (file.endsWith(".patch"))
      text = text
        .split("\n")
        .filter((line) => !line.startsWith("-"))
        .join("\n");
    for (const match of text.matchAll(REF_RE)) {
      const ref = match[0].replace(/[.]+$/, "");
      if (!refs.has(ref)) refs.set(ref, file);
    }
  }
  return refs;
}

// Where a bundle's manifests can be read: its build output, else its fetched
// source, else nowhere.
export function bundleSource(entry: BundleEntry): BundleSource {
  if (fs.existsSync(entry.out)) return "built";
  if (entry.src && fs.existsSync(entry.src)) return "source";
  return "unavailable";
}

// The dsh bundle manifests under a bundle's build output or source.
export function bundleManifests(
  entry: BundleEntry,
  source: BundleSource = bundleSource(entry),
  overrideVersion?: string,
): { dir: string; manifest: Manifest }[] {
  const root =
    source === "built"
      ? path.join(entry.out, "lib/node_modules")
      : source === "source"
        ? entry.src
        : null;
  if (!root) return [];
  const manifests: { dir: string; manifest: Manifest }[] = [];
  for (const file of walk(root, { maxDepth: source === "built" ? 2 : 3 })) {
    if (path.basename(file) !== "package.json") continue;
    let manifest: Manifest;
    try {
      manifest = readJson<Manifest>(file);
    } catch {
      continue;
    }
    if (!manifest.dsh?.bundle) continue;
    // The builder writes the target runtime version into engines.dsh when enabled.
    if (entry.overrideDshEngineVersion && overrideVersion)
      manifest.engines = { ...manifest.engines, dsh: overrideVersion };
    manifests.push({ dir: path.dirname(file), manifest });
  }
  return manifests;
}
