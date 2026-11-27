import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import test, { type TestContext } from "node:test";
import {
  BUNDLES_TS,
  CLI_MANIFEST,
  GenerateError,
  optionalBundles,
} from "./optional-bundles.ts";

const bundlesTs = `export const PROFILE_TEMPLATES: Record<string, ProfileTemplate> = {
  web: {
    bundles: ['@deepseek-ai/dsh-base', '@deepseek-ai/dsh-web-app'],
  },
}

export const OPTIONAL_BUNDLES: readonly string[] = [
  // Ships switched off.
  '@deepseek-ai/dsh-zeta',
  "@deepseek-ai/dsh-alpha", // trailing comment

  '@deepseek-ai/dsh-zeta',
]
`;

function tree(t: TestContext, files: Record<string, string | object>): string {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "optional-bundles-"));
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  for (const [file, content] of Object.entries(files)) {
    fs.mkdirSync(path.dirname(path.join(root, file)), { recursive: true });
    fs.writeFileSync(
      path.join(root, file),
      typeof content === "string" ? content : JSON.stringify(content),
    );
  }
  return root;
}

const upstream = (overrides: Record<string, string | object> = {}) => ({
  [BUNDLES_TS]: bundlesTs,
  [CLI_MANIFEST]: {
    dependencies: {
      "@deepseek-ai/dsh-alpha": "workspace:*",
      "@deepseek-ai/dsh-zeta": "workspace:*",
    },
  },
  "packages/bundle/alpha/package.json": {
    name: "@deepseek-ai/dsh-alpha",
    description: "Alpha from the manifest",
    dependencies: { "@deepseek-ai/dsh-panel": "workspace:*", left: "1" },
    dsh: { bundle: { patch: "./patch.yml", platforms: ["linux"] } },
  },
  "packages/bundle/alpha/patch.yml":
    "- insert:\n    - id: panel\n      name: '@deepseek-ai/dsh-panel'\n",
  "packages/bundle/alpha/locale/zh.json": { meta: { description: "阿尔法" } },
  "packages/bundle/zeta/package.json": {
    name: "@deepseek-ai/dsh-zeta",
    dependencies: { "@deepseek-ai/dsh-panel": "workspace:*" },
    dsh: { bundle: { patch: ["./a.yml"] } },
  },
  "packages/bundle/zeta/a.yml":
    "- insert:\n    - id: panel-extra\n      name: '@deepseek-ai/dsh-panel-extra'\n",
  "packages/bundle/zeta/locale/en.json": { meta: { description: "Zeta" } },
  "packages/bundle/zeta/locale/zh.json": { meta: { description: "泽塔" } },
  "packages/bundle/zeta/locale/ja.json": "not json",
  "packages/ui/panel/package.json": {
    name: "@deepseek-ai/dsh-panel",
    peerDependencies: { "@deepseek-ai/dsh-api-terminal-controller": "*" },
  },
  ...overrides,
});

test("collects sorted members with descriptions, web needs, and platforms", (t) => {
  const warnings: string[] = [];
  const result = optionalBundles(tree(t, upstream()), (message) =>
    warnings.push(message),
  );
  assert.deepEqual(Object.keys(result), [
    "@deepseek-ai/dsh-alpha",
    "@deepseek-ai/dsh-zeta",
  ]);
  assert.deepEqual(result["@deepseek-ai/dsh-alpha"], {
    attr: "alpha",
    pname: "dsh-alpha",
    description: "Alpha from the manifest",
    descriptionZh: "阿尔法",
    descriptionJa: "Alpha from the manifest",
    requiresWeb: true,
    platforms: ["linux"],
  });
  assert.deepEqual(result["@deepseek-ai/dsh-zeta"], {
    attr: "zeta",
    pname: "dsh-zeta",
    description: "Zeta",
    descriptionZh: "泽塔",
    descriptionJa: "Zeta",
    requiresWeb: false,
    platforms: [],
  });
  assert.deepEqual(warnings, [
    "@deepseek-ai/dsh-alpha has no Japanese description; using English",
    "@deepseek-ai/dsh-zeta has no Japanese description; using English",
  ]);
});

test("rejects members the installation cannot ship as optional", (t) => {
  const cases: [Record<string, string | object>, RegExp][] = [
    [{ [BUNDLES_TS]: "export const X = 1\n" }, /OPTIONAL_BUNDLES is missing/],
    [
      {
        [BUNDLES_TS]: bundlesTs.replace(
          "'@deepseek-ai/dsh-zeta',\n]",
          "dshZeta,\n]",
        ),
      },
      /unexpected OPTIONAL_BUNDLES line:\s+dshZeta,/,
    ],
    [
      { [BUNDLES_TS]: bundlesTs.replace("dsh-web-app", "dsh-zeta") },
      /dsh-zeta is selected by a shipped profile template/,
    ],
    [
      { [CLI_MANIFEST]: { dependencies: { "@deepseek-ai/dsh-alpha": "*" } } },
      /dsh-zeta is not an installation dependency/,
    ],
    [
      {
        "packages/bundle/zeta/package.json": { name: "@deepseek-ai/dsh-zeta" },
      },
      /dsh-zeta is not a workspace bundle/,
    ],
    [
      {
        "packages/bundle/zeta/locale/en.json": {},
      },
      /dsh-zeta has no description/,
    ],
  ];
  for (const [overrides, message] of cases)
    assert.throws(
      () => optionalBundles(tree(t, upstream(overrides))),
      (error) => error instanceof GenerateError && message.test(error.message),
    );
  assert.throws(
    () => optionalBundles(tree(t, {})),
    /is this an upstream source tree/,
  );
});
