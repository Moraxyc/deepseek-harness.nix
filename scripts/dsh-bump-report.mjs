#!/usr/bin/env node
// Static impact report for a deepseek-harness (dsh-workspace) bump.
// Run through scripts/dsh-bump-report.sh, which resolves the inputs.

import { execFileSync } from "node:child_process";
import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { parseArgs } from "node:util";

const { values: args } = parseArgs({
  options: {
    old: { type: "string" },
    new: { type: "string" },
    repo: { type: "string" },
    "app-boot": { type: "string" },
    bundles: { type: "string" },
    json: { type: "boolean", default: false },
    strict: { type: "boolean", default: false },
  },
});
for (const required of ["old", "new", "repo"]) {
  if (!args[required]) throw new Error(`--${required} is required`);
}

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

function progress(message) {
  process.stderr.write(`dsh-bump-report: ${message}\n`);
}

function readJson(file) {
  return JSON.parse(fs.readFileSync(file, "utf8"));
}

function yamlToJson(file, query = ".") {
  return JSON.parse(
    execFileSync("yq", ["-o=json", query, file], { encoding: "utf8" }),
  );
}

function sha(file) {
  return crypto
    .createHash("sha256")
    .update(fs.readFileSync(file))
    .digest("hex");
}

function* walk(root, { maxDepth = Infinity, depth = 0 } = {}) {
  let entries;
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

// ── workspace inventory ─────────────────────────────────────────────────────

function matchGlob(root, pattern) {
  let dirs = [root];
  for (const segment of pattern.split("/")) {
    const next = [];
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

function inventory(root) {
  const workspace = yamlToJson(path.join(root, "pnpm-workspace.yaml"));
  const packages = new Map();
  for (const pattern of workspace.packages ?? []) {
    if (pattern.startsWith("!")) continue;
    for (const dir of matchGlob(root, pattern)) {
      const manifestPath = path.join(dir, "package.json");
      if (!fs.existsSync(manifestPath)) continue;
      const manifest = readJson(manifestPath);
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
            .map((key) => [key, manifest.scripts[key]]),
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

function exportAllows(exportKeys, subpath) {
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

// Valid means the package exists and exports the subpath.
function refStatus(inv, ref) {
  const [scope, name, ...rest] = ref.split("/");
  const pkg = inv.packages.get(`${scope}/${name}`);
  if (!pkg) return "missing-package";
  if (rest.length === 0) return "ok";
  return exportAllows(pkg.exports, `./${rest.join("/")}`) ? "ok" : "unexported";
}

// ── upstream bundle rows and official bundle lists ─────────────────────────

function bundlePatchFiles(root, pkg) {
  if (!pkg.bundle) return [];
  const declared = Array.isArray(pkg.bundle.patch)
    ? pkg.bundle.patch
    : [pkg.bundle.patch];
  const files = declared
    .filter((file) => typeof file === "string")
    .map((file) => path.join(root, pkg.dir, file));
  const presets = path.join(root, pkg.dir, "presets");
  if (fs.existsSync(presets)) {
    for (const entry of fs.readdirSync(presets)) {
      if (entry.endsWith(".yml")) files.push(path.join(presets, entry));
    }
  }
  return files.filter((file) => fs.existsSync(file));
}

function rowsOf(file) {
  try {
    return yamlToJson(
      file,
      '[.. | select(tag == "!!map" and has("id")) | {"id": .id, "name": (.name // null)}]',
    );
  } catch {
    return [];
  }
}

function upstreamRows(root, inv) {
  const rows = new Map();
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

function officialLists(root) {
  for (const file of walk(path.join(root, "packages"), { maxDepth: 4 })) {
    if (!file.endsWith(".ts")) continue;
    const text = fs.readFileSync(file, "utf8");
    if (!text.includes("export const OPTIONAL_BUNDLES")) continue;
    const lists = {};
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

// ── comparisons ────────────────────────────────────────────────────────────

function diffSets(before, after) {
  return {
    added: [...after].filter((item) => !before.has(item)).sort(),
    removed: [...before].filter((item) => !after.has(item)).sort(),
  };
}

function diffKeys(before = {}, after = {}) {
  const changed = [];
  for (const key of new Set([...Object.keys(before), ...Object.keys(after)])) {
    if (JSON.stringify(before[key]) !== JSON.stringify(after[key]))
      changed.push(key);
  }
  return changed.sort();
}

function comparePackages(oldInv, newInv) {
  const names = diffSets(
    new Set(oldInv.packages.keys()),
    new Set(newInv.packages.keys()),
  );
  const moved = [];
  const removedExports = [];
  const lifecycle = [];
  const bin = [];
  const bundle = [];
  const native = [];
  for (const [name, after] of newInv.packages) {
    const before = oldInv.packages.get(name);
    if (!before) {
      if (Object.keys(after.lifecycle).length)
        lifecycle.push({ name, after: after.lifecycle });
      if (after.native) native.push({ name, dir: after.dir });
      if (after.bundle) bundle.push({ name, change: "added" });
      continue;
    }
    if (before.dir !== after.dir)
      moved.push({ name, from: before.dir, to: after.dir });
    if (before.exports && after.exports) {
      const gone = before.exports.filter((key) => !after.exports.includes(key));
      if (gone.length) removedExports.push({ name, subpaths: gone });
    }
    if (JSON.stringify(before.lifecycle) !== JSON.stringify(after.lifecycle))
      lifecycle.push({
        name,
        before: before.lifecycle,
        after: after.lifecycle,
      });
    if (JSON.stringify(before.bin) !== JSON.stringify(after.bin))
      bin.push({ name, before: before.bin, after: after.bin });
    if (JSON.stringify(before.bundle) !== JSON.stringify(after.bundle))
      bundle.push({
        name,
        change: after.bundle
          ? before.bundle
            ? "changed"
            : "added"
          : "removed",
      });
    if (!before.native && after.native) native.push({ name, dir: after.dir });
  }
  for (const name of names.removed) {
    if (oldInv.packages.get(name).bundle)
      bundle.push({ name, change: "removed" });
  }
  return { ...names, moved, removedExports, lifecycle, bin, bundle, native };
}

function compareBuildInputs(oldRoot, newRoot, oldInv, newInv) {
  const rootOld = readJson(path.join(oldRoot, "package.json"));
  const rootNew = readJson(path.join(newRoot, "package.json"));
  const files = (root, dir) =>
    fs.existsSync(path.join(root, dir))
      ? [...walk(path.join(root, dir))].map((file) => path.relative(root, file))
      : [];
  const changedFiles = (list) =>
    list.filter((file) => {
      const a = path.join(oldRoot, file);
      const b = path.join(newRoot, file);
      if (!fs.existsSync(a) || !fs.existsSync(b)) return true;
      return sha(a) !== sha(b);
    });
  const patchFiles = new Set([
    ...files(oldRoot, "patches"),
    ...files(newRoot, "patches"),
  ]);
  const tracked = [
    "tsdown.config.ts",
    "Makefile",
    "scripts/build.ts",
    "apps/cli/package.json",
    "apps/desktop/package.json",
    "apps/desktop/electron-builder.yml",
    "native/system/package.json",
  ];
  return {
    rootScripts: diffKeys(rootOld.scripts, rootNew.scripts).filter((key) =>
      key.startsWith("build"),
    ),
    rootFields: diffKeys(
      {
        packageManager: rootOld.packageManager,
        engines: rootOld.engines,
        pnpm: rootOld.pnpm,
      },
      {
        packageManager: rootNew.packageManager,
        engines: rootNew.engines,
        pnpm: rootNew.pnpm,
      },
    ),
    workspaceKeys: diffKeys(
      { ...oldInv.workspace, packages: undefined },
      { ...newInv.workspace, packages: undefined },
    ),
    workspaceGlobs: diffSets(
      new Set(oldInv.workspace.packages ?? []),
      new Set(newInv.workspace.packages ?? []),
    ),
    patches: changedFiles([...patchFiles].sort()),
    files: changedFiles(
      tracked.filter(
        (file) =>
          fs.existsSync(path.join(oldRoot, file)) ||
          fs.existsSync(path.join(newRoot, file)),
      ),
    ),
  };
}

// ── this repository ────────────────────────────────────────────────────────

function localPatchTargets(repo, oldRoot, newRoot) {
  const dir = path.join(repo, "pkgs/dsh-workspace");
  const packageNix = fs.readFileSync(path.join(dir, "package.nix"), "utf8");
  // Only the derivation's own patch list applies to the upstream tree.
  const sourcePatches = new Set(
    [
      ...(
        packageNix.match(/\n  patches = \[([\s\S]*?)\n  \];/)?.[1] ?? ""
      ).matchAll(/\.\/([A-Za-z0-9._-]+\.patch)/g),
    ].map((match) => match[1]),
  );
  const targets = new Map();
  for (const entry of fs.readdirSync(dir)) {
    const file = path.join(dir, entry);
    const text = fs.readFileSync(file, "utf8");
    if (entry.endsWith(".patch")) {
      if (!sourcePatches.has(entry)) continue;
      // Files the patch creates have no upstream counterpart.
      for (const match of text.matchAll(
        /^--- (\S+)[^\n]*\n\+\+\+ b\/(\S+)/gm,
      )) {
        if (match[1] !== "/dev/null") targets.set(match[2], entry);
      }
    } else if (entry.endsWith(".nix") || entry.endsWith(".sh")) {
      for (const match of text.matchAll(
        /(?:^|["'\s])((?:apps|packages|native|vendor|scripts)\/[A-Za-z0-9._@/-]+)/gm,
      )) {
        const candidate = match[1].replace(/[/.]+$/, "");
        if (candidate.includes("${")) continue;
        if (fs.existsSync(path.join(oldRoot, candidate)))
          targets.set(candidate, entry);
      }
    }
  }
  const result = [];
  for (const [target, owner] of [...targets].sort()) {
    const a = path.join(oldRoot, target);
    const b = path.join(newRoot, target);
    let status;
    if (!fs.existsSync(b)) status = "missing";
    else if (!fs.existsSync(a)) status = "new";
    else if (fs.statSync(a).isDirectory()) status = "present";
    else status = sha(a) === sha(b) ? "unchanged" : "changed";
    result.push({ target, owner, status });
  }
  return result;
}

function scanRefs(files) {
  const refs = new Map();
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

// A reference regresses when the old tree resolved it and the new one does not.
function regressedRefs(refs, oldInv, newInv) {
  const result = [];
  for (const [ref, file] of refs) {
    if (refStatus(oldInv, ref) !== "ok") continue;
    const status = refStatus(newInv, ref);
    if (status !== "ok") result.push({ ref, status, file });
  }
  return result.sort((a, b) => a.ref.localeCompare(b.ref));
}

// Rows a downstream patch targets by id alone must exist upstream.
function staleRowTargets(files, oldRows, newRows) {
  const result = [];
  for (const file of files) {
    if (!/\.ya?ml$/.test(file)) continue;
    for (const row of rowsOf(file)) {
      if (typeof row.id !== "string" || row.name) continue;
      if (oldRows.has(row.id) && !newRows.has(row.id))
        result.push({ id: row.id, file });
    }
  }
  return result;
}

function bundleManifests(entry) {
  const roots = [];
  if (entry.outExists)
    roots.push({
      kind: "built",
      root: path.join(entry.out, "lib/node_modules"),
    });
  else if (entry.src) roots.push({ kind: "source", root: entry.src });
  const manifests = [];
  for (const { kind, root } of roots) {
    for (const file of walk(root, { maxDepth: kind === "built" ? 2 : 3 })) {
      if (path.basename(file) !== "package.json") continue;
      let manifest;
      try {
        manifest = readJson(file);
      } catch {
        continue;
      }
      if (!manifest.dsh?.bundle) continue;
      if (kind === "source" && entry.dshEngines)
        manifest.engines = { ...manifest.engines, dsh: entry.dshEngines };
      manifests.push({ kind, file, dir: path.dirname(file), manifest });
    }
  }
  return manifests;
}

// ── main ───────────────────────────────────────────────────────────────────

progress("indexing workspaces");
const oldInv = inventory(args.old);
const newInv = inventory(args.new);
const newVersion = newInv.packages.get("@deepseek-ai/dsh-app-boot")?.version;
const oldVersion = oldInv.packages.get("@deepseek-ai/dsh-app-boot")?.version;
const oldRows = upstreamRows(args.old, oldInv);
const newRows = upstreamRows(args.new, newInv);
const oldLists = officialLists(args.old);
const newLists = officialLists(args.new);

progress("comparing");
const report = {
  versions: { old: oldVersion, new: newVersion },
  packages: comparePackages(oldInv, newInv),
  buildInputs: compareBuildInputs(args.old, args.new, oldInv, newInv),
  officialLists: Object.fromEntries(
    [
      ...new Set([
        ...Object.keys(oldLists.lists),
        ...Object.keys(newLists.lists),
      ]),
    ]
      .sort()
      .map((name) => [
        name,
        diffSets(
          new Set(oldLists.lists[name] ?? []),
          new Set(newLists.lists[name] ?? []),
        ),
      ])
      .filter(([, change]) => change.added.length || change.removed.length),
  ),
  rows: diffSets(new Set(oldRows.keys()), new Set(newRows.keys())),
  localPatchTargets: localPatchTargets(args.repo, args.old, args.new),
  repoRefs: regressedRefs(
    scanRefs(
      ["pkgs", "lib", "modules"].flatMap((dir) =>
        [...walk(path.join(args.repo, dir))].filter(
          (file) =>
            !/pkgs\/dsh-workspace\/(pnpm-lock|pnpm-workspace|optional-bundles)\.json$/.test(
              file,
            ),
        ),
      ),
    ),
    oldInv,
    newInv,
  ),
  bundles: [],
};

let evaluate = null;
if (args["app-boot"]) {
  ({ evaluatePluginCompatibility: evaluate } = await import(
    path.join(args["app-boot"], "lib/index.js")
  ));
}

const repoBundleFiles = (attr) => [
  ...walk(path.join(args.repo, "pkgs/bundles", attr)),
];

for (const entry of args.bundles ? readJson(args.bundles) : []) {
  if (entry.workspace) continue;
  progress(`bundle ${entry.attr}`);
  const result = {
    attr: entry.attr,
    version: entry.version,
    dshEngines: entry.dshEngines ?? null,
    source: entry.outExists ? "built" : entry.src ? "source" : "unavailable",
    gate: [],
    refs: [],
    staleRows: [],
  };
  const manifests = bundleManifests(entry);
  const files = [];
  for (const { dir, manifest } of manifests) {
    if (evaluate && newVersion) {
      const issue = evaluate(manifest, {}, newVersion);
      if (issue)
        result.gate.push({
          name: manifest.name,
          version: manifest.version,
          unmet: Object.keys(issue.requirements),
        });
    }
    for (const file of walk(dir)) files.push(file);
  }
  files.push(...repoBundleFiles(entry.attr));
  result.refs = regressedRefs(scanRefs(files), oldInv, newInv).map(
    ({ ref, status }) => ({ ref, status }),
  );
  result.staleRows = staleRowTargets(files, oldRows, newRows).map(
    ({ id, file }) => ({
      id,
      file: path.basename(file),
    }),
  );
  report.bundles.push(result);
}

// ── findings that need a downstream decision ───────────────────────────────

const actions = [];
const pkgs = report.packages;
const build = report.buildInputs;
if (
  report.localPatchTargets.some(
    (t) => t.status === "missing" || t.status === "changed",
  )
)
  actions.push(
    "Rebase or re-check pkgs/dsh-workspace patches and path references whose upstream target changed or disappeared.",
  );
if (
  build.workspaceKeys.length ||
  build.workspaceGlobs.added.length ||
  build.workspaceGlobs.removed.length
)
  actions.push(
    `Review pnpm-workspace.yaml changes (${[...build.workspaceKeys, ...build.workspaceGlobs.added, ...build.workspaceGlobs.removed].join(", ")}) against importPnpmLock and dshWorkspacePatchHook.`,
  );
if (
  build.rootScripts.length ||
  build.rootFields.length ||
  build.files.length ||
  build.patches.length
)
  actions.push(
    "Review build entry points and patched dependencies for dsh-workspace buildPhase/installPhase impact.",
  );
if (pkgs.native.length || pkgs.lifecycle.length)
  actions.push(
    "New native code or install scripts: check strictDeps, sandbox builds, and whether a separate Nix package (like dsh-system or dsh-cua-native) is needed.",
  );
if (pkgs.bin.length)
  actions.push(
    "bin entries changed: check the dsh wrapper and desktop launchers.",
  );
if (pkgs.bundle.length || Object.keys(report.officialLists).length)
  actions.push(
    "Official bundle set changed: run generate-optional-bundles.sh (update.sh does) and check removed-bundles.nix, presets, and migration docs.",
  );
if (pkgs.removed.length || pkgs.removedExports.length || pkgs.moved.length)
  actions.push(
    "Packages or exports were removed or moved: check every downstream reference listed below.",
  );
if (report.repoRefs.length)
  actions.push(
    "This repository references upstream packages or exports that no longer resolve.",
  );
// Builds can rewrite manifests (pnpm deploy, postPatch), so a source manifest
// only suggests a rejection.
const unverified = report.bundles
  .filter((bundle) => bundle.gate.length && bundle.source !== "built")
  .map((bundle) => bundle.attr);
if (unverified.length)
  actions.push(
    `Source manifests suggest dsh ${newVersion} rejects: ${unverified.join(", ")}. Confirm with their bundleCompositions or scripts/dsh-bundle-probe.sh.`,
  );
for (const bundle of report.bundles) {
  if (bundle.gate.length && bundle.source === "built")
    actions.push(
      `bundles.${bundle.attr}: dsh ${newVersion} rejects it (${bundle.gate.map((g) => `${g.name}: ${g.unmet.length} unmet`).join("; ")}). Probe it, then set dshEngines, patch it, or mark it broken.`,
    );
  if (bundle.refs.length)
    actions.push(
      `bundles.${bundle.attr}: references that no longer resolve: ${bundle.refs.map((r) => r.ref).join(", ")}.`,
    );
  if (bundle.staleRows.length)
    actions.push(
      `bundles.${bundle.attr}: patches target rows upstream removed: ${bundle.staleRows.map((r) => r.id).join(", ")}.`,
    );
}
report.actions = actions;

// ── output ─────────────────────────────────────────────────────────────────

function list(items, render = (item) => `\`${item}\``) {
  return items.length
    ? items.map((item) => `- ${render(item)}`).join("\n")
    : "- none";
}

if (args.json) {
  process.stdout.write(`${JSON.stringify(report, null, 2)}\n`);
} else {
  const out = [];
  out.push(`# dsh-workspace ${oldVersion} -> ${newVersion}`);
  out.push(
    "",
    "## Actions",
    "",
    list(actions, (a) => a),
  );
  out.push("", "## Workspace packages", "");
  out.push(`Added (${pkgs.added.length}):`, list(pkgs.added));
  out.push("", `Removed (${pkgs.removed.length}):`, list(pkgs.removed));
  out.push(
    "",
    "Moved:",
    list(pkgs.moved, (m) => `\`${m.name}\`: ${m.from} -> ${m.to}`),
  );
  out.push(
    "",
    "Removed exports:",
    list(pkgs.removedExports, (e) => `\`${e.name}\`: ${e.subpaths.join(", ")}`),
  );
  out.push(
    "",
    "Install scripts:",
    list(pkgs.lifecycle, (l) => `\`${l.name}\`: ${JSON.stringify(l.after)}`),
  );
  out.push(
    "",
    "New native code:",
    list(pkgs.native, (n) => `\`${n.name}\` (${n.dir})`),
  );
  out.push(
    "",
    "bin changes:",
    list(pkgs.bin, (b) => `\`${b.name}\``),
  );
  out.push("", "## Official bundles", "");
  out.push(
    "Bundle manifests:",
    list(pkgs.bundle, (b) => `\`${b.name}\` ${b.change}`),
  );
  for (const [name, change] of Object.entries(report.officialLists)) {
    out.push(
      "",
      `${name}:`,
      list(
        [
          ...change.added.map((n) => `+ ${n}`),
          ...change.removed.map((n) => `- ${n}`),
        ],
        (n) => n,
      ),
    );
  }
  out.push(
    "",
    `Rows removed (${report.rows.removed.length}):`,
    list(report.rows.removed),
  );
  out.push(
    "",
    `Rows added (${report.rows.added.length}):`,
    list(report.rows.added),
  );
  out.push("", "## Build inputs", "");
  out.push("Root build scripts:", list(build.rootScripts));
  out.push("", "Root fields:", list(build.rootFields));
  out.push("", "pnpm-workspace.yaml keys:", list(build.workspaceKeys));
  out.push(
    "",
    "Workspace globs:",
    list(
      [
        ...build.workspaceGlobs.added.map((g) => `+ ${g}`),
        ...build.workspaceGlobs.removed.map((g) => `- ${g}`),
      ],
      (g) => g,
    ),
  );
  out.push("", "Patched dependencies (patches/):", list(build.patches));
  out.push("", "Tracked files:", list(build.files));
  out.push("", "## pkgs/dsh-workspace references", "");
  out.push(
    list(
      report.localPatchTargets.filter(
        (t) => t.status !== "unchanged" && t.status !== "present",
      ),
      (t) => `${t.status}: \`${t.target}\` (${t.owner})`,
    ),
  );
  out.push("", "## Repository references", "");
  out.push(
    list(
      report.repoRefs,
      (r) => `${r.status}: \`${r.ref}\` (${path.relative(args.repo, r.file)})`,
    ),
  );
  out.push("", "## Bundles", "");
  if (!report.bundles.length) out.push("- not evaluated");
  else {
    out.push(
      "Source rows read the fetched source without this repository's patches; build the bundle for exact results.",
      "",
    );
    out.push(
      "| bundle | version | source | dshEngines | gate | stale refs | stale rows |",
    );
    out.push("| --- | --- | --- | --- | --- | --- | --- |");
    for (const b of report.bundles) {
      const unmet = b.gate.map((g) => g.unmet.length).join("+");
      const gate = b.gate.length
        ? b.source === "built"
          ? `rejected (${unmet} unmet)`
          : `likely rejected (${unmet} unmet)`
        : evaluate
          ? "ok"
          : "n/a";
      out.push(
        `| ${b.attr} | ${b.version} | ${b.source} | ${b.dshEngines ?? ""} | ${gate} | ${b.refs.map((r) => r.ref).join("<br>")} | ${b.staleRows.map((r) => r.id).join("<br>")} |`,
      );
    }
  }
  process.stdout.write(`${out.join("\n")}\n`);
}

if (args.strict && actions.length) process.exitCode = 1;
