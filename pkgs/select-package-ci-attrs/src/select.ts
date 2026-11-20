import { isDeepStrictEqual } from "node:util";

// legacyPackages.ciPackageAttrs: attr names mapped to installables.
export interface PackageSet {
  packages: Record<string, string>;
  bundles: Record<string, string>;
  presets: Record<string, string>;
  bundleCompositions: Record<string, string>;
  bundleDependents: Record<string, string[]>;
}

export type Change =
  { kind: "global" } | { kind: "package" | "bundle" | "preset"; name: string };

const GLOBAL: Change = { kind: "global" };

// A trailing slash matches the directory and everything below it.
const UNTRACKED = [
  // Maintenance tools that Package CI builds as checks.
  "lib/catalog.nix",
  "fetchrix.toml",
  "pkgs/dsh-bump-report/",
];
const GLOBAL_PATHS = [
  ".github/workflows/package-ci.yml",
  "default.nix",
  "flake.nix",
  "flake.lock",
  "lib/",
  "modules/",
  "overlays/",
  "scripts/default.nix",
  "scripts/nix-run",
  "pkgs/select-package-ci-attrs/",
  "pkgs/generate-optional-bundles/",
  "pkgs/dsh-runtime/",
  "pkgs/dsh-workspace/",
  "pkgs/dsh-profile-smoke/",
  "pkgs/importPnpmLock/",
];

const matches = (file: string, patterns: string[]) =>
  patterns.some((pattern) =>
    pattern.endsWith("/") ? file.startsWith(pattern) : file === pattern,
  );

// The first path component of FILE below DIR.
const nameUnder = (file: string, dir: string) =>
  file.slice(dir.length + 1).split("/")[0] as string;

// What a fetchrix package key builds.
export function sourceChange(key: string): Change {
  if (key === "dsh-workspace" || key === "dsh-runtime") return GLOBAL;
  if (key.startsWith("bundles."))
    return { kind: "bundle", name: key.slice("bundles.".length) };
  return { kind: "package", name: key };
}

interface Lock {
  packages?: Record<string, unknown>;
  [key: string]: unknown;
}

// The packages whose _sources/lock.json entry differs. Anything else that
// changed, or a missing side, affects every package.
export function lockChanges(
  before: string | undefined,
  after: string | undefined,
): Change[] {
  if (before === undefined || after === undefined) return [GLOBAL];
  let old: Lock, current: Lock;
  try {
    old = JSON.parse(before) as Lock;
    current = JSON.parse(after) as Lock;
  } catch {
    return [GLOBAL];
  }
  const { packages: oldPackages = {}, ...oldMetadata } = old;
  const { packages: newPackages = {}, ...newMetadata } = current;
  if (!isDeepStrictEqual(oldMetadata, newMetadata)) return [GLOBAL];
  const keys = new Set([
    ...Object.keys(oldPackages),
    ...Object.keys(newPackages),
  ]);
  return [...keys]
    .filter((key) => !isDeepStrictEqual(oldPackages[key], newPackages[key]))
    .map(sourceChange);
}

// What a changed file affects. LOCK_CHANGES resolves a lock.json change.
export function classify(file: string, lockChanges: () => Change[]): Change[] {
  if (matches(file, UNTRACKED)) return [];
  if (matches(file, GLOBAL_PATHS)) return [GLOBAL];
  if (file === "_sources/lock.json") return lockChanges();
  if (file.startsWith("_sources/"))
    return [sourceChange(nameUnder(file, "_sources"))];
  if (file.startsWith("pkgs/dsh/")) return [{ kind: "package", name: "dsh" }];
  if (file.startsWith("pkgs/bundles/"))
    return [{ kind: "bundle", name: nameUnder(file, "pkgs/bundles") }];
  if (file.startsWith("pkgs/presets/"))
    return [{ kind: "preset", name: nameUnder(file, "pkgs/presets") }];
  if (file.startsWith("pkgs/"))
    return [{ kind: "package", name: nameUnder(file, "pkgs") }];
  return [];
}

function attrsOf(change: Change, set: PackageSet): string[] | undefined {
  switch (change.kind) {
    case "global":
      return undefined;
    case "package": {
      const own = set.packages[change.name];
      if (own === undefined) return undefined;
      if (change.name !== "dsh") return [own];
      // Both desktop variants embed the composed dsh as their runtime.
      const desktops = [
        "dsh-desktop",
        "dsh-desktop-official",
        "dsh-desktop-unofficial",
      ].flatMap((name) => set.packages[name] ?? []);
      return [
        own,
        ...desktops,
        ...Object.values(set.presets),
        ...Object.values(set.bundleCompositions),
      ];
    }
    case "bundle": {
      const own = set.bundles[change.name];
      if (own === undefined) return undefined;
      // A bundle build succeeds even when dsh would skip the bundle at
      // runtime; its composition boots it through dsh-profile-smoke.
      const composition = set.bundleCompositions[change.name];
      return [
        own,
        ...(composition === undefined ? [] : [composition]),
        ...(set.bundleDependents[change.name] ?? []),
      ];
    }
    case "preset": {
      const own = set.presets[change.name];
      return own === undefined ? undefined : [own];
    }
  }
}

// The sorted attrs to build. A global or unknown change selects everything.
export function selectAttrs(changes: Change[], set: PackageSet): string[] {
  const selected: string[] = [];
  for (const change of changes) {
    const attrs = attrsOf(change, set);
    if (attrs === undefined) {
      selected.length = 0;
      selected.push(
        ...Object.values(set.packages),
        ...Object.values(set.bundles),
        ...Object.values(set.presets),
        ...Object.values(set.bundleCompositions),
      );
      break;
    }
    selected.push(...attrs);
  }
  return [...new Set(selected)].sort();
}
