// Declares the upstream installation as one pnpm importer, apps/nix-runtime:
// the dsh CLI and the private Desktop Host, plus every peer of the workspace
// packages they reach. pnpm deploy alone omits those peers because the
// workspace disables autoInstallPeers. Optional peers are included as well,
// which is what dsh has always shipped with.
//
// usage: node runtime-importer.mjs OVERRIDES_JSON LOCKFILE_JSON
// Run from the workspace root. Writes apps/nix-runtime/package.json and prints
// the importer entry for pnpm-lock.yaml.

import {
  existsSync,
  mkdirSync,
  readdirSync,
  readFileSync,
  statSync,
  writeFileSync,
} from "node:fs";
import path from "node:path";
import { pathToFileURL } from "node:url";

const ROOTS = {
  "@deepseek-ai/dsh": "workspace:*",
  "@deepseek-ai/dsh-desktop-host": "workspace:*",
};
const IMPORTER = "apps/nix-runtime";
const REQUIRED_FILES = [
  "apps/cli/package.json",
  "apps/desktop-host/package.json",
  "pnpm-lock.yaml",
  "pnpm-workspace.yaml",
];

const readJson = (file) => JSON.parse(readFileSync(file, "utf8"));
const sortKeys = (object) =>
  Object.fromEntries(
    Object.entries(object).sort(([a], [b]) => (a < b ? -1 : a > b ? 1 : 0)),
  );

const children = (dir) =>
  existsSync(dir) && statSync(dir).isDirectory()
    ? readdirSync(dir)
        .sort()
        .map((name) => path.join(dir, name))
    : [];

// Manifests under apps/*, vendor/* and packages/*/*, keyed by package name.
export function readManifests(root) {
  const dirs = [
    ...children(path.join(root, "apps")),
    ...children(path.join(root, "vendor")),
    ...children(path.join(root, "packages")).flatMap(children),
  ];
  const manifests = {};
  for (const dir of dirs) {
    const file = path.join(dir, "package.json");
    if (!existsSync(file)) continue;
    const manifest = readJson(file);
    if (manifest.name == null) continue;
    const relative = path.relative(root, dir);
    if (manifests[manifest.name])
      throw new Error(
        `${manifest.name} is declared by both ${manifests[manifest.name].path} and ${relative}`,
      );
    manifests[manifest.name] = {
      path: relative,
      dependencies: manifest.dependencies ?? {},
      peers: manifest.peerDependencies ?? {},
    };
  }
  return manifests;
}

// Workspace dependencies are followed only to find their peers; pnpm installs
// external dependencies transitively. A specifier already selected wins.
export function runtimeDependencies(manifests) {
  let selected = { ...ROOTS };
  for (;;) {
    let next = selected;
    for (const name of Object.keys(selected).sort()) {
      const manifest = manifests[name];
      if (!manifest) continue;
      const workspaceDependencies = Object.fromEntries(
        Object.entries(manifest.dependencies).filter(
          ([dependency]) => manifests[dependency],
        ),
      );
      next = { ...workspaceDependencies, ...manifest.peers, ...next };
    }
    if (Object.keys(next).length === Object.keys(selected).length)
      return selected;
    selected = next;
  }
}

// Workspace links are importer-relative, so they are rebuilt for apps/nix-runtime.
// Upstream link: overrides stay links; external packages reuse their lock entry.
export function runtimeImporter({ manifests, overrides, lockfile }) {
  const locked = {};
  for (const importer of Object.values(lockfile.importers ?? {}))
    Object.assign(locked, importer.devDependencies, importer.dependencies);

  const dependencies = {};
  const missing = [];
  for (const [name, specifier] of Object.entries(
    runtimeDependencies(manifests),
  )) {
    const workspacePath = manifests[name]?.path;
    if (workspacePath != null) {
      const link = `link:../../${workspacePath}`;
      dependencies[name] = {
        specifier: /^link:/.test(overrides[name] ?? "") ? link : specifier,
        version: link,
      };
    } else if (
      locked[name]?.specifier != null &&
      locked[name]?.version != null
    ) {
      dependencies[name] = locked[name];
    } else {
      missing.push(name);
    }
  }
  if (missing.length > 0)
    throw new Error(
      `runtime dependencies missing from the workspace lockfile: ${missing.join(", ")}`,
    );

  const sorted = sortKeys(dependencies);
  return {
    packageJson: {
      name: "@deepseek-ai/dsh-nix-runtime",
      version: "0.0.0",
      private: true,
      dependencies: Object.fromEntries(
        Object.entries(sorted).map(([name, entry]) => [name, entry.specifier]),
      ),
    },
    importer: { dependencies: sorted },
  };
}

function main([overridesFile, lockfileFile, ...rest]) {
  if (!overridesFile || !lockfileFile || rest.length > 0)
    throw new Error("usage: runtime-importer.mjs OVERRIDES_JSON LOCKFILE_JSON");
  const root = process.cwd();
  for (const file of REQUIRED_FILES)
    if (!existsSync(path.join(root, file)))
      throw new Error(`expected workspace file ${file}`);

  const { packageJson, importer } = runtimeImporter({
    manifests: readManifests(root),
    overrides: readJson(overridesFile),
    lockfile: readJson(lockfileFile),
  });
  mkdirSync(path.join(root, IMPORTER), { recursive: true });
  writeFileSync(
    path.join(root, IMPORTER, "package.json"),
    `${JSON.stringify(packageJson, null, 2)}\n`,
  );
  process.stdout.write(`${JSON.stringify(importer)}\n`);
}

if (
  process.argv[1] &&
  import.meta.url === pathToFileURL(process.argv[1]).href
) {
  try {
    main(process.argv.slice(2));
  } catch (error) {
    console.error(`runtime-importer: ${error.message}`);
    process.exit(1);
  }
}
