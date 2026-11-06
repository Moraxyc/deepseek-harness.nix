#!/usr/bin/env node
// Replace bundle dependencies with links into the dsh installation, so both
// load one module instance. @deepseek-ai packages always follow the
// installation's release; other packages are shared only at the same version.
// usage: share-installation-packages.mjs BUNDLE_NODE_MODULES INSTALLATION_NODE_MODULES [KEEP...]

import fs from "node:fs";
import path from "node:path";

const [bundleRoot, installationRoot, ...keep] = process.argv.slice(2);
if (!bundleRoot || !installationRoot) {
  console.error(
    "usage: share-installation-packages.mjs BUNDLE_NODE_MODULES INSTALLATION_NODE_MODULES [KEEP...]",
  );
  process.exit(1);
}
const kept = new Set(keep);

function manifest(packageDir) {
  try {
    return JSON.parse(
      fs.readFileSync(path.join(packageDir, "package.json"), "utf8"),
    );
  } catch {
    return undefined;
  }
}

function isDirectory(file) {
  try {
    return fs.statSync(file).isDirectory();
  } catch {
    return false;
  }
}

// Package entries, real or linked (pnpm's isolated layout links them into .pnpm).
function packageDirs(modules) {
  const dirs = [];
  for (const entry of fs.readdirSync(modules)) {
    if (entry.startsWith(".")) continue;
    const entryPath = path.join(modules, entry);
    if (!isDirectory(entryPath)) continue;
    if (entry.startsWith("@")) {
      for (const scoped of fs.readdirSync(entryPath)) {
        const scopedPath = path.join(entryPath, scoped);
        if (isDirectory(scopedPath))
          dirs.push([`${entry}/${scoped}`, scopedPath]);
      }
    } else {
      dirs.push([entry, entryPath]);
    }
  }
  return dirs;
}

let shared = 0;
function visit(modules) {
  for (const [name, dir] of packageDirs(modules)) {
    const own = manifest(dir);
    const installed = path.join(installationRoot, name);
    const carried = manifest(installed)?.version;
    // Bundle packages stay in place: the manifest step rewrites and records them.
    if (
      !kept.has(name) &&
      own !== undefined &&
      own.dsh?.bundle === undefined &&
      carried !== undefined &&
      (name.startsWith("@deepseek-ai/") || own.version === carried)
    ) {
      fs.rmSync(dir, { recursive: true, force: true });
      fs.symlinkSync(installed, dir);
      shared += 1;
      continue;
    }
    if (fs.lstatSync(dir).isSymbolicLink()) continue;
    const nested = path.join(dir, "node_modules");
    if (fs.existsSync(nested) && fs.lstatSync(nested).isDirectory())
      visit(nested);
  }
  const store = path.join(modules, ".pnpm");
  if (fs.existsSync(store) && fs.lstatSync(store).isDirectory()) {
    for (const entry of fs.readdirSync(store)) {
      const nested = path.join(store, entry, "node_modules");
      if (fs.existsSync(nested) && fs.lstatSync(nested).isDirectory())
        visit(nested);
    }
  }
}

visit(bundleRoot);
console.log(`share-installation-packages: linked ${shared} packages`);
