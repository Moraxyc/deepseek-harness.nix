import assert from "node:assert/strict";
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { readManifests, runtimeImporter } from "./runtime-importer.mjs";

function workspace(t, packages) {
  const root = mkdtempSync(path.join(os.tmpdir(), "runtime-importer-"));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  for (const [dir, manifest] of Object.entries(packages)) {
    mkdirSync(path.join(root, dir), { recursive: true });
    writeFileSync(
      path.join(root, dir, "package.json"),
      JSON.stringify(manifest),
    );
  }
  return root;
}

const roots = {
  "apps/cli": {
    name: "@deepseek-ai/dsh",
    dependencies: { "@deepseek-ai/core": "workspace:*", lodash: "^4.0.0" },
  },
  "apps/desktop-host": { name: "@deepseek-ai/dsh-desktop-host" },
};

const lockfile = {
  importers: {
    "apps/cli": {
      dependencies: { lodash: { specifier: "^4.0.0", version: "4.17.21" } },
      devDependencies: { react: { specifier: "^18.0.0", version: "18.2.0" } },
    },
  },
};

test("follows workspace dependencies to their peers", (t) => {
  const root = workspace(t, {
    ...roots,
    "packages/core/core": {
      name: "@deepseek-ai/core",
      peerDependencies: {
        "@deepseek-ai/schema": "workspace:~",
        react: "^18.0.0",
      },
      peerDependenciesMeta: { react: { optional: true } },
    },
    "vendor/schema": { name: "@deepseek-ai/schema" },
    "packages/core/unused": { name: "@deepseek-ai/unused" },
  });
  const { packageJson, importer } = runtimeImporter({
    manifests: readManifests(root),
    overrides: { "@deepseek-ai/schema": "link:./vendor/schema" },
    lockfile,
  });

  assert.deepEqual(packageJson.dependencies, {
    "@deepseek-ai/core": "workspace:*",
    "@deepseek-ai/dsh": "workspace:*",
    "@deepseek-ai/dsh-desktop-host": "workspace:*",
    "@deepseek-ai/schema": "link:../../vendor/schema",
    react: "^18.0.0",
  });
  assert.deepEqual(importer.dependencies["@deepseek-ai/core"], {
    specifier: "workspace:*",
    version: "link:../../packages/core/core",
  });
  assert.deepEqual(importer.dependencies.react, {
    specifier: "^18.0.0",
    version: "18.2.0",
  });
  assert.equal(importer.dependencies.lodash, undefined);
});

test("rejects a peer missing from the lockfile", (t) => {
  const root = workspace(t, {
    ...roots,
    "packages/core/core": {
      name: "@deepseek-ai/core",
      peerDependencies: { vue: "^3.0.0" },
    },
  });
  assert.throws(
    () =>
      runtimeImporter({
        manifests: readManifests(root),
        overrides: {},
        lockfile,
      }),
    /missing from the workspace lockfile: vue/,
  );
});

test("rejects duplicate package names", (t) => {
  const root = workspace(t, {
    ...roots,
    "packages/a/core": { name: "@deepseek-ai/core" },
    "packages/b/core": { name: "@deepseek-ai/core" },
  });
  assert.throws(
    () => readManifests(root),
    /declared by both packages\/a\/core and packages\/b\/core/,
  );
});
