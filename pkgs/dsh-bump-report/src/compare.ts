// Compares two upstream workspace trees and what this repository relies on.

import fs from "node:fs";
import path from "node:path";
import {
  type BundleEntry,
  type BundleSource,
  type Inventory,
  type Manifest,
  type Rows,
  type WorkspacePackage,
  bundleManifests,
  bundleSource,
  inventory,
  officialLists,
  readJson,
  refStatus,
  rowsOf,
  scanRefs,
  sha,
  upstreamRows,
  walk,
} from "./inventory.ts";

export interface SetDiff {
  added: string[];
  removed: string[];
}

export interface RegressedRef {
  ref: string;
  status: string;
  file: string;
}

export interface BundleResult {
  attr: string;
  version: string;
  overrideDshEngineVersion: boolean;
  source: BundleSource;
  gate: { name?: string; version?: string; unmet: string[] }[];
  refs: { ref: string; status: string }[];
  staleRows: { id: string; file: string }[];
}

// dsh-app-boot's evaluatePluginCompatibility.
export type Evaluate = (
  manifest: Manifest,
  options: object,
  version: string,
) => { requirements: Record<string, unknown> } | null | undefined;

interface WorkspaceComparison {
  oldInv: Inventory;
  newInv: Inventory;
  newVersion: string | undefined;
  oldRows: Rows;
  newRows: Rows;
}

export type PatchTarget = ReturnType<typeof localPatchTargets>[number];

export interface Report {
  versions: { old: string | undefined; new: string | undefined };
  packages: ReturnType<typeof comparePackages>;
  buildInputs: ReturnType<typeof compareBuildInputs>;
  officialLists: Record<string, SetDiff>;
  rows: SetDiff;
  localPatchTargets: PatchTarget[];
  repoRefs: RegressedRef[];
  gateEvaluated: boolean;
  bundles: BundleResult[];
  actions: string[];
}

export function diffSets(before: Set<string>, after: Set<string>): SetDiff {
  return {
    added: [...after].filter((item) => !before.has(item)).sort(),
    removed: [...before].filter((item) => !after.has(item)).sort(),
  };
}

export function diffKeys(
  before: Record<string, unknown> = {},
  after: Record<string, unknown> = {},
): string[] {
  const changed: string[] = [];
  for (const key of new Set([...Object.keys(before), ...Object.keys(after)])) {
    if (JSON.stringify(before[key]) !== JSON.stringify(after[key]))
      changed.push(key);
  }
  return changed.sort();
}

export function comparePackages(oldInv: Inventory, newInv: Inventory) {
  const names = diffSets(
    new Set(oldInv.packages.keys()),
    new Set(newInv.packages.keys()),
  );
  const moved: { name: string; from: string; to: string }[] = [];
  const removedExports: { name: string; subpaths: string[] }[] = [];
  const lifecycle: {
    name: string;
    before?: WorkspacePackage["lifecycle"];
    after: WorkspacePackage["lifecycle"];
  }[] = [];
  const bin: { name: string; before: unknown; after: unknown }[] = [];
  const bundle: { name: string; change: "added" | "changed" | "removed" }[] =
    [];
  const native: { name: string; dir: string }[] = [];
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
      const gone = before.exports.filter(
        (key) => !after.exports?.includes(key),
      );
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
    if (oldInv.packages.get(name)?.bundle)
      bundle.push({ name, change: "removed" });
  }
  return { ...names, moved, removedExports, lifecycle, bin, bundle, native };
}

const TRACKED_BUILD_FILES = [
  "tsdown.config.ts",
  "Makefile",
  "scripts/build.ts",
  "apps/cli/package.json",
  "apps/desktop/package.json",
  "apps/desktop/electron-builder.yml",
  "native/system/package.json",
];

interface RootManifest {
  scripts?: Record<string, string>;
  packageManager?: string;
  engines?: unknown;
  pnpm?: unknown;
}

export function compareBuildInputs(
  oldRoot: string,
  newRoot: string,
  oldInv: Inventory,
  newInv: Inventory,
) {
  const rootOld = readJson<RootManifest>(path.join(oldRoot, "package.json"));
  const rootNew = readJson<RootManifest>(path.join(newRoot, "package.json"));
  const files = (root: string, dir: string) =>
    fs.existsSync(path.join(root, dir))
      ? [...walk(path.join(root, dir))].map((file) => path.relative(root, file))
      : [];
  const changedFiles = (list: string[]) =>
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
  const rootFields = (manifest: RootManifest) => ({
    packageManager: manifest.packageManager,
    engines: manifest.engines,
    pnpm: manifest.pnpm,
  });
  return {
    rootScripts: diffKeys(rootOld.scripts, rootNew.scripts).filter((key) =>
      key.startsWith("build"),
    ),
    rootFields: diffKeys(rootFields(rootOld), rootFields(rootNew)),
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
      TRACKED_BUILD_FILES.filter(
        (file) =>
          fs.existsSync(path.join(oldRoot, file)) ||
          fs.existsSync(path.join(newRoot, file)),
      ),
    ),
  };
}

// Lists with members added or removed, keyed by list name.
export function compareOfficialLists(
  oldLists: Record<string, string[]>,
  newLists: Record<string, string[]>,
): Record<string, SetDiff> {
  return Object.fromEntries(
    [...new Set([...Object.keys(oldLists), ...Object.keys(newLists)])]
      .sort()
      .map((name): [string, SetDiff] => [
        name,
        diffSets(new Set(oldLists[name] ?? []), new Set(newLists[name] ?? [])),
      ])
      .filter(([, change]) => change.added.length || change.removed.length),
  );
}

// Upstream paths that pkgs/dsh-workspace patches or names, and how they changed.
export function localPatchTargets(
  repo: string,
  oldRoot: string,
  newRoot: string,
) {
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
  const targets = new Map<string, string>();
  for (const entry of fs.readdirSync(dir)) {
    const file = path.join(dir, entry);
    const text = fs.readFileSync(file, "utf8");
    if (entry.endsWith(".patch")) {
      if (!sourcePatches.has(entry)) continue;
      // Files the patch creates have no upstream counterpart.
      for (const match of text.matchAll(
        /^--- (\S+)[^\n]*\n\+\+\+ b\/(\S+)/gm,
      )) {
        if (match[1] !== "/dev/null") targets.set(match[2] ?? "", entry);
      }
    } else if (entry.endsWith(".nix") || entry.endsWith(".sh")) {
      for (const match of text.matchAll(
        /(?:^|["'\s])((?:apps|packages|native|vendor|scripts)\/[A-Za-z0-9._@/-]+)/gm,
      )) {
        const candidate = (match[1] ?? "").replace(/[/.]+$/, "");
        if (candidate.includes("${")) continue;
        if (fs.existsSync(path.join(oldRoot, candidate)))
          targets.set(candidate, entry);
      }
    }
  }
  type Status = "missing" | "new" | "present" | "unchanged" | "changed";
  const result: { target: string; owner: string; status: Status }[] = [];
  for (const [target, owner] of [...targets].sort()) {
    const a = path.join(oldRoot, target);
    const b = path.join(newRoot, target);
    let status: Status;
    if (!fs.existsSync(b)) status = "missing";
    else if (!fs.existsSync(a)) status = "new";
    else if (fs.statSync(a).isDirectory()) status = "present";
    else status = sha(a) === sha(b) ? "unchanged" : "changed";
    result.push({ target, owner, status });
  }
  return result;
}

// A reference regresses when the old tree resolved it and the new one does not.
export function regressedRefs(
  refs: Map<string, string>,
  oldInv: Inventory,
  newInv: Inventory,
): RegressedRef[] {
  const result: RegressedRef[] = [];
  for (const [ref, file] of refs) {
    if (refStatus(oldInv, ref) !== "ok") continue;
    const status = refStatus(newInv, ref);
    if (status !== "ok") result.push({ ref, status, file });
  }
  return result.sort((a, b) => a.ref.localeCompare(b.ref));
}

// Rows a downstream patch targets by id alone must exist upstream.
export function staleRowTargets(
  files: string[],
  oldRows: Rows,
  newRows: Rows,
): { id: string; file: string }[] {
  const result: { id: string; file: string }[] = [];
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

// One bundle from `nix eval` (attr, version, out, src, overrideDshEngineVersion) against the
// new workspace. `evaluate` is dsh-app-boot's evaluatePluginCompatibility.
export function compareBundle(
  entry: BundleEntry,
  {
    repo,
    workspace,
    evaluate,
  }: {
    repo: string;
    workspace: WorkspaceComparison;
    evaluate: Evaluate | null;
  },
): BundleResult {
  const source = bundleSource(entry);
  const gate: BundleResult["gate"] = [];
  const files: string[] = [];
  for (const { dir, manifest } of bundleManifests(
    entry,
    source,
    workspace.newVersion,
  )) {
    if (evaluate && workspace.newVersion) {
      const issue = evaluate(manifest, {}, workspace.newVersion);
      if (issue)
        gate.push({
          name: manifest.name,
          version: manifest.version,
          unmet: Object.keys(issue.requirements),
        });
    }
    files.push(...walk(dir));
  }
  files.push(...walk(path.join(repo, "pkgs/bundles", entry.attr)));
  return {
    attr: entry.attr,
    version: entry.version,
    overrideDshEngineVersion: entry.overrideDshEngineVersion ?? false,
    source,
    gate,
    refs: regressedRefs(
      scanRefs(files),
      workspace.oldInv,
      workspace.newInv,
    ).map(({ ref, status }) => ({ ref, status })),
    staleRows: staleRowTargets(files, workspace.oldRows, workspace.newRows).map(
      ({ id, file }) => ({ id, file: path.basename(file) }),
    ),
  };
}

// Findings that need a downstream decision.
export function actionsOf(report: Omit<Report, "actions">): string[] {
  const actions: string[] = [];
  const { packages: pkgs, buildInputs: build, versions } = report;
  if (
    report.localPatchTargets.some(
      (t) => t.status === "missing" || t.status === "changed",
    )
  )
    actions.push(
      "Rebase or re-check pkgs/dsh-workspace patches and path references whose upstream target changed or disappeared.",
    );
  const workspaceChanges = [
    ...build.workspaceKeys,
    ...build.workspaceGlobs.added,
    ...build.workspaceGlobs.removed,
  ];
  if (workspaceChanges.length)
    actions.push(
      `Review pnpm-workspace.yaml changes (${workspaceChanges.join(", ")}) against importPnpmLock and pkgs/dsh-workspace/runtime-importer.mjs.`,
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
      "Official bundle set changed: run `fetchrix update dsh-workspace` and check removed-bundles.nix, presets, and migration docs.",
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
      `Source manifests suggest dsh ${versions.new} rejects: ${unverified.join(", ")}. Confirm with their bundleCompositions or tools.dsh-bundle-probe.`,
    );
  const overridden = report.bundles
    .filter((bundle) => bundle.overrideDshEngineVersion)
    .map((bundle) => bundle.attr);
  if (overridden.length)
    actions.push(
      `Bundles with overrideDshEngineVersion enabled (${overridden.join(", ")}): confirm with their bundleCompositions or tools.dsh-bundle-probe.`,
    );
  for (const bundle of report.bundles) {
    if (bundle.gate.length && bundle.source === "built")
      actions.push(
        `bundles.${bundle.attr}: dsh ${versions.new} rejects it (${bundle.gate.map((g) => `${g.name}: ${g.unmet.length} unmet`).join("; ")}). Probe it, then set overrideDshEngineVersion = true, patch it, or mark it broken.`,
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
  return actions;
}

const LOCK_ARTIFACT =
  /pkgs\/dsh-workspace\/(pnpm-lock|pnpm-workspace|optional-bundles)\.json$/;

// The full report for upgrading the workspace at oldRoot to the one at newRoot.
export function buildReport({
  oldRoot,
  newRoot,
  repo,
  bundles = [],
  evaluate = null,
  progress = () => {},
}: {
  oldRoot: string;
  newRoot: string;
  repo: string;
  bundles?: BundleEntry[];
  evaluate?: Evaluate | null;
  progress?: (message: string) => void;
}): Report {
  progress("indexing workspaces");
  const oldInv = inventory(oldRoot);
  const newInv = inventory(newRoot);
  const workspace: WorkspaceComparison = {
    oldInv,
    newInv,
    newVersion: newInv.packages.get("@deepseek-ai/dsh-app-boot")?.version,
    oldRows: upstreamRows(oldRoot, oldInv),
    newRows: upstreamRows(newRoot, newInv),
  };

  progress("comparing");
  const repoFiles = ["pkgs", "lib", "modules"].flatMap((dir) =>
    [...walk(path.join(repo, dir))].filter((file) => !LOCK_ARTIFACT.test(file)),
  );
  const partial: Omit<Report, "actions"> = {
    versions: {
      old: oldInv.packages.get("@deepseek-ai/dsh-app-boot")?.version,
      new: workspace.newVersion,
    },
    packages: comparePackages(oldInv, newInv),
    buildInputs: compareBuildInputs(oldRoot, newRoot, oldInv, newInv),
    officialLists: compareOfficialLists(
      officialLists(oldRoot).lists,
      officialLists(newRoot).lists,
    ),
    rows: diffSets(
      new Set(workspace.oldRows.keys()),
      new Set(workspace.newRows.keys()),
    ),
    localPatchTargets: localPatchTargets(repo, oldRoot, newRoot),
    repoRefs: regressedRefs(scanRefs(repoFiles), oldInv, newInv).map((ref) => ({
      ...ref,
      file: path.relative(repo, ref.file),
    })),
    gateEvaluated: evaluate !== null,
    bundles: [],
  };
  for (const entry of bundles) {
    if (entry.workspace) continue;
    progress(`bundle ${entry.attr}`);
    partial.bundles.push(compareBundle(entry, { repo, workspace, evaluate }));
  }
  return { ...partial, actions: actionsOf(partial) };
}
