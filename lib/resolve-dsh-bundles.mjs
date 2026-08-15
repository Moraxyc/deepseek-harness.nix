#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";

function die(message) {
  throw new Error(`dsh bundle resolver: ${message}`);
}

function readJson(file) {
  try {
    return JSON.parse(fs.readFileSync(file, "utf8"));
  } catch (error) {
    die(`cannot read ${file}: ${error.message}`);
  }
}

function isDirectory(file) {
  try {
    return fs.statSync(file).isDirectory();
  } catch {
    return false;
  }
}

function packageRoots(root) {
  if (!isDirectory(root))
    die(`bundle root is missing or not a directory: ${root}`);

  const roots = [];
  for (const entry of fs.readdirSync(root, { withFileTypes: true })) {
    const entryPath = path.join(root, entry.name);
    if (!isDirectory(entryPath)) continue;

    if (entry.name.startsWith("@")) {
      for (const scopedEntry of fs.readdirSync(entryPath, {
        withFileTypes: true,
      })) {
        const packagePath = path.join(entryPath, scopedEntry.name);
        if (isDirectory(packagePath)) roots.push(packagePath);
      }
    } else {
      roots.push(entryPath);
    }
  }
  return roots;
}

function packageNameFromPath(root, packageRoot) {
  const relative = path.relative(root, packageRoot);
  const parts = relative.split(path.sep);
  if (parts.length === 1) return parts[0];
  if (parts.length === 2 && parts[0].startsWith("@"))
    return `${parts[0]}/${parts[1]}`;
  die(`cannot determine package name from output path: ${packageRoot}`);
}

function bundleMetadata(packageRoot, root) {
  const manifestPath = path.join(packageRoot, "package.json");
  if (!fs.existsSync(manifestPath)) return null;

  const manifest = readJson(manifestPath);
  const bundle = manifest.dsh?.bundle;
  if (bundle === undefined) return null;

  if (!bundle || typeof bundle !== "object" || Array.isArray(bundle)) {
    die(`${manifestPath} has an invalid dsh.bundle value`);
  }
  if (typeof bundle.patch !== "string" || bundle.patch.length === 0) {
    die(`${manifestPath} must declare dsh.bundle.patch as a non-empty string`);
  }
  if (typeof manifest.name !== "string" || manifest.name.length === 0) {
    die(`${manifestPath} must declare a non-empty name`);
  }
  if (typeof manifest.version !== "string" || manifest.version.length === 0) {
    die(`${manifestPath} must declare a non-empty version`);
  }

  const expectedName = packageNameFromPath(root, packageRoot);
  if (manifest.name !== expectedName) {
    die(
      `${manifestPath} name '${manifest.name}' does not match output package '${expectedName}'`,
    );
  }

  if (!bundle.patch.startsWith("./") || bundle.patch.includes("\\")) {
    die(`${manifestPath} dsh.bundle.patch must be a relative './...' path`);
  }
  const patchPath = path.resolve(packageRoot, bundle.patch);
  const relativePatch = path.relative(packageRoot, patchPath);
  if (relativePatch.startsWith("..") || path.isAbsolute(relativePatch)) {
    die(`${manifestPath} dsh.bundle.patch escapes the package root`);
  }
  if (!fs.existsSync(patchPath) || !fs.statSync(patchPath).isFile()) {
    die(`${manifestPath} dsh.bundle.patch does not exist: ${bundle.patch}`);
  }

  return {
    name: manifest.name,
    version: manifest.version,
    patch: bundle.patch,
    packageRoot,
  };
}

function mergeMetadata(metadataGroups) {
  const byName = new Map();
  for (const metadata of metadataGroups.flat()) {
    const previous = byName.get(metadata.name);
    if (previous) {
      if (
        previous.version !== metadata.version ||
        previous.patch !== metadata.patch
      ) {
        die(
          `conflicting bundle metadata for ${metadata.name}: ` +
            `${previous.version} (${previous.packageRoot}) vs ` +
            `${metadata.version} (${metadata.packageRoot})`,
        );
      }
      continue;
    }
    byName.set(metadata.name, metadata);
  }

  if (byName.size === 0) die("no package declares dsh.bundle.patch");
  return [...byName.values()].sort((left, right) =>
    left.name.localeCompare(right.name),
  );
}

function resolveBundles(roots) {
  if (roots.length === 0) die("at least one bundle root is required");

  const metadata = [];
  for (const root of roots) {
    for (const packageRoot of packageRoots(root)) {
      const bundle = bundleMetadata(packageRoot, root);
      if (bundle) metadata.push(bundle);
    }
  }

  return mergeMetadata([metadata]);
}

function readManifest(file) {
  const manifest = readJson(file);
  if (manifest.schema !== 1 || !Array.isArray(manifest.bundles)) {
    die(`${file} is not a dsh bundle manifest with schema 1`);
  }

  for (const bundle of manifest.bundles) {
    if (
      !bundle ||
      typeof bundle.name !== "string" ||
      typeof bundle.version !== "string" ||
      typeof bundle.patch !== "string" ||
      typeof bundle.packageRoot !== "string"
    ) {
      die(`${file} contains invalid bundle metadata`);
    }
    const packageRoot = bundle.packageRoot;
    const root = bundle.name.startsWith("@")
      ? path.dirname(path.dirname(packageRoot))
      : path.dirname(packageRoot);
    const actual = bundleMetadata(packageRoot, root);
    if (!actual || JSON.stringify(actual) !== JSON.stringify(bundle)) {
      die(`${file} does not match its package output: ${packageRoot}`);
    }
  }
  return manifest.bundles;
}

function mergeManifests(files) {
  if (files.length === 0) die("at least one bundle manifest is required");
  return mergeMetadata(files.map(readManifest));
}

function writeJson(file, value) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, `${JSON.stringify(value, null, 2)}\n`);
}

function usage() {
  return [
    "usage:",
    "  resolve-dsh-bundles.mjs check ROOT...",
    "  resolve-dsh-bundles.mjs manifest OUTPUT ROOT...",
    "  resolve-dsh-bundles.mjs merge OUTPUT MANIFEST...",
    "  resolve-dsh-bundles.mjs profile OUTPUT PROFILE MANIFEST...",
  ].join("\n");
}

function main(argv) {
  const [command, output, ...arguments_] = argv;
  if (!command) die(usage());

  if (command === "check") {
    resolveBundles([output, ...arguments_]);
    return;
  }

  if (command === "manifest") {
    if (!output || arguments_.length === 0) die(usage());
    writeJson(output, { schema: 1, bundles: resolveBundles(arguments_) });
    return;
  }

  if (command === "merge") {
    if (!output || arguments_.length === 0) die(usage());
    writeJson(output, { schema: 1, bundles: mergeManifests(arguments_) });
    return;
  }

  if (command === "profile") {
    if (!output || arguments_.length < 2) die(usage());
    const profile = arguments_[0];
    const bundles = mergeManifests(arguments_.slice(1));
    writeJson(output, {
      name: `dsh-profile-${profile}`,
      private: true,
      dependencies: {},
      dsh: { profile: { bundles: bundles.map((bundle) => bundle.name) } },
    });
    return;
  }

  die(usage());
}

try {
  main(process.argv.slice(2));
} catch (error) {
  console.error(error.message);
  process.exitCode = 1;
}
