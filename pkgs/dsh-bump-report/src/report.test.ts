import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { test } from "node:test";
import { type Evaluate, buildReport } from "./compare.ts";
import { exportAllows } from "./inventory.ts";
import { renderMarkdown } from "./render.ts";

function tree(files: Record<string, string | object>): string {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "dsh-bump-report-"));
  for (const [file, content] of Object.entries(files)) {
    fs.mkdirSync(path.dirname(path.join(root, file)), { recursive: true });
    fs.writeFileSync(
      path.join(root, file),
      typeof content === "string" ? content : JSON.stringify(content),
    );
  }
  return root;
}

const workspaceFile = "packages:\n  - packages/*\n";
const web = {
  name: "@deepseek-ai/dsh-web",
  version: "1.0.0",
  dsh: { bundle: { patch: "patch.yml" } },
};

const oldRoot = tree({
  "package.json": { name: "root", scripts: { build: "a" } },
  "pnpm-workspace.yaml": workspaceFile,
  "packages/app-boot/package.json": {
    name: "@deepseek-ai/dsh-app-boot",
    version: "1.0.0",
    exports: { ".": "./i.js", "./old": "./o.js" },
  },
  "packages/web/package.json": web,
  "packages/web/patch.yml":
    '- id: web.panel\n  name: Panel\n  disabled: !!js "!ctx"\n- id: web.gone\n',
});
const newRoot = tree({
  "package.json": { name: "root", scripts: { build: "b" } },
  "pnpm-workspace.yaml": workspaceFile,
  "packages/app-boot/package.json": {
    name: "@deepseek-ai/dsh-app-boot",
    version: "2.0.0",
    exports: { ".": "./i.js" },
  },
  "packages/web/package.json": web,
  "packages/web/patch.yml": "- id: web.panel\n  name: Panel\n",
  "packages/native/package.json": {
    name: "@deepseek-ai/dsh-native",
    gypfile: true,
    scripts: { postinstall: "node-gyp rebuild" },
  },
});
const repo = tree({
  "pkgs/dsh-workspace/package.nix": "{\n  patches = [\n  ];\n}\n",
  "lib/uses.nix": '"@deepseek-ai/dsh-app-boot/old"\n',
  "pkgs/bundles/foo/rows.yml": "- id: web.gone\n",
});
const fooSource = tree({
  "package.json": { name: "dsh-foo", version: "1", dsh: { bundle: {} } },
});

// Accepts only manifests whose engines.dsh names the running version.
const evaluate: Evaluate = (manifest, _, version) =>
  manifest.engines?.dsh === version ? null : { requirements: { dsh: version } };

const report = buildReport({
  oldRoot,
  newRoot,
  repo,
  evaluate,
  bundles: [
    {
      attr: "foo",
      version: "1",
      out: path.join(repo, "missing-output"),
      src: fooSource,
      srcDrv: null,
      dshEngines: "1.0.0",
      workspace: false,
    },
    {
      attr: "workspace-bundle",
      version: "",
      out: "",
      src: null,
      srcDrv: null,
      dshEngines: null,
      workspace: true,
    },
  ],
});

test("subpath patterns in exports", () => {
  assert.ok(exportAllows(["./lib/*.js"], "./lib/a.js"));
  assert.ok(!exportAllows(["./lib/*.js"], "./lib/a.cjs"));
  assert.ok(exportAllows(null, "./anything"));
});

test("workspace changes", () => {
  assert.deepEqual(report.versions, { old: "1.0.0", new: "2.0.0" });
  assert.deepEqual(report.packages.added, ["@deepseek-ai/dsh-native"]);
  assert.deepEqual(report.packages.removedExports, [
    { name: "@deepseek-ai/dsh-app-boot", subpaths: ["./old"] },
  ]);
  assert.deepEqual(
    report.packages.native.map((p) => p.name),
    ["@deepseek-ai/dsh-native"],
  );
  assert.deepEqual(report.buildInputs.rootScripts, ["build"]);
  assert.deepEqual(report.rows, { added: [], removed: ["web.gone"] });
});

test("repository references are relative to the repository", () => {
  assert.deepEqual(report.repoRefs, [
    {
      ref: "@deepseek-ai/dsh-app-boot/old",
      status: "unexported",
      file: "lib/uses.nix",
    },
  ]);
});

test("unbuilt bundles are read from their source with dshEngines applied", () => {
  assert.equal(report.bundles.length, 1);
  const [foo] = report.bundles;
  assert.ok(foo);
  assert.equal(foo.source, "source");
  assert.deepEqual(foo.gate, [
    { name: "dsh-foo", version: "1", unmet: ["dsh"] },
  ]);
  assert.deepEqual(foo.staleRows, [{ id: "web.gone", file: "rows.yml" }]);
  assert.ok(
    report.actions.includes(
      "Source manifests suggest dsh 2.0.0 rejects: foo. Confirm with their bundleCompositions or tools.dsh-bundle-probe.",
    ),
  );
});

test("markdown lists actions and the bundle table", () => {
  const markdown = renderMarkdown(report);
  assert.ok(markdown.startsWith("# dsh-workspace 1.0.0 -> 2.0.0\n"));
  for (const action of report.actions)
    assert.ok(markdown.includes(`- ${action}\n`));
  assert.ok(
    markdown.includes(
      "| foo | 1 | source | 1.0.0 | likely rejected (1 unmet) |  | web.gone |",
    ),
  );
  assert.ok(
    markdown.includes(
      "unexported: `@deepseek-ai/dsh-app-boot/old` (lib/uses.nix)",
    ),
  );
});
