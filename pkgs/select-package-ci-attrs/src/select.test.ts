import assert from "node:assert/strict";
import test from "node:test";
import {
  type Change,
  type PackageSet,
  classify,
  lockChanges,
  selectAttrs,
} from "./select.ts";

const set: PackageSet = {
  packages: {
    dsh: ".#dsh",
    "dsh-desktop": ".#dsh-desktop",
    "dsh-desktop-official": ".#dsh-desktop-official",
    "dsh-desktop-unofficial": ".#dsh-desktop-unofficial",
    "dsh-runtime": ".#dsh-runtime",
  },
  bundles: { tui: ".#bundles.tui", base: ".#bundles.base" },
  presets: { tui: ".#presets.tui" },
  bundleCompositions: { tui: ".#bundleCompositions.tui" },
  bundleDependents: { tui: [".#presets.tui"], base: [] },
};
const all = [
  ...Object.values(set.packages),
  ...Object.values(set.bundles),
  ...Object.values(set.presets),
  ...Object.values(set.bundleCompositions),
].sort();
const noLock = () => assert.fail("unexpected lock.json read");

test("classifies changed files", () => {
  const cases: [string, Change[]][] = [
    ["README.md", []],
    ["pkgs/dsh-bump-report/src/cli.ts", []],
    ["lib/catalog.nix", []],
    ["lib/mk-dsh-bundle.nix", [{ kind: "global" }]],
    ["pkgs/select-package-ci-attrs/src/select.ts", [{ kind: "global" }]],
    ["pkgs/dsh/package.nix", [{ kind: "package", name: "dsh" }]],
    ["pkgs/bundles/tui/package.nix", [{ kind: "bundle", name: "tui" }]],
    ["pkgs/presets/tui/package.nix", [{ kind: "preset", name: "tui" }]],
    [
      "pkgs/dsh-cua-native/package.nix",
      [{ kind: "package", name: "dsh-cua-native" }],
    ],
    ["_sources/bundles.tui/pnpm-lock.json", [{ kind: "bundle", name: "tui" }]],
    ["_sources/dsh-workspace/pnpm-lock.json", [{ kind: "global" }]],
  ];
  for (const [file, expected] of cases)
    assert.deepEqual(classify(file, noLock), expected, file);
});

test("selects only the lock.json entries that changed", () => {
  const lock = (packages: object, schema = 1) =>
    JSON.stringify({ schema, packages });
  const before = lock({
    "bundles.tui": { v: 1 },
    "dsh-desktop-unofficial": { v: 1 },
  });
  assert.deepEqual(
    lockChanges(
      before,
      lock({ "bundles.tui": { v: 2 }, "dsh-desktop-unofficial": { v: 1 } }),
    ),
    [{ kind: "bundle", name: "tui" }],
  );
  assert.deepEqual(lockChanges(before, lock({ "bundles.tui": { v: 1 } })), [
    { kind: "package", name: "dsh-desktop-unofficial" },
  ]);
  assert.deepEqual(
    lockChanges(
      before,
      lock({ "bundles.tui": { v: 1 }, "dsh-desktop-unofficial": { v: 1 } }, 2),
    ),
    [{ kind: "global" }],
  );
  assert.deepEqual(lockChanges(undefined, before), [{ kind: "global" }]);
});

test("expands changes into attrs", () => {
  assert.deepEqual(selectAttrs([], set), []);
  assert.deepEqual(selectAttrs([{ kind: "bundle", name: "tui" }], set), [
    ".#bundleCompositions.tui",
    ".#bundles.tui",
    ".#presets.tui",
  ]);
  assert.deepEqual(selectAttrs([{ kind: "package", name: "dsh" }], set), [
    ".#bundleCompositions.tui",
    ".#dsh",
    ".#dsh-desktop",
    ".#dsh-desktop-official",
    ".#dsh-desktop-unofficial",
    ".#presets.tui",
  ]);
  assert.deepEqual(selectAttrs([{ kind: "global" }], set), all);
  assert.deepEqual(
    selectAttrs(
      [
        { kind: "preset", name: "tui" },
        { kind: "bundle", name: "missing" },
      ],
      set,
    ),
    all,
  );
});
