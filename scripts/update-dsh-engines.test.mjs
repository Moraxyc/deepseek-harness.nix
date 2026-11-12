import assert from "node:assert/strict";
import {
  mkdtempSync,
  mkdirSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { updateEngines } from "./update-dsh-engines.mjs";

const version = "0.2.2-rc.3";
const oldVersion = "0.2.2-rc.2";

function fixture(t, sources) {
  const root = mkdtempSync(path.join(os.tmpdir(), "dsh-engines-"));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  const file = (name) => path.join(root, "pkgs/bundles", name, "package.nix");
  for (const [name, source] of Object.entries(sources)) {
    mkdirSync(path.dirname(file(name)), { recursive: true });
    writeFileSync(file(name), source);
  }
  return {
    root,
    read: (name) => readFileSync(file(name), "utf8"),
    run: (options) =>
      updateEngines({ root, version, report: () => {}, ...options }),
  };
}

const source = `{
  # 已验证 / verified
  # dshEngines = "not a declaration";
  dshEngines = "${oldVersion}";
  version = "1.0.0";
}\n`;
const candidate = (name) => ({ name, dshEngines: oldVersion });

test("writes an exact grant before the boot check and retains it only on success", (t) => {
  const f = fixture(t, { example: source });
  const calls = [];
  assert.equal(
    f.run({
      bundles: [candidate("example")],
      build: (names) => {
        calls.push(names);
        assert.equal(f.read("example"), source.replace(oldVersion, version));
        return true;
      },
    }),
    true,
  );
  assert.deepEqual(calls, [["example"], ["example"]]);
  assert.equal(f.read("example"), source.replace(oldVersion, version));
});

test("skips bundles without a grant and grants already at the workspace version", (t) => {
  const f = fixture(t, {});
  assert.equal(
    f.run({
      bundles: [
        { name: "upstream", dshEngines: null },
        { name: "current", dshEngines: version },
      ],
      build: () => assert.fail("unexpected build"),
    }),
    true,
  );
});

test("restores a failed candidate, keeps passing candidates, and reports failure", (t) => {
  const f = fixture(t, { broken: source, working: source });
  const calls = [];
  assert.equal(
    f.run({
      bundles: [candidate("broken"), candidate("working")],
      build: (names) => {
        calls.push(names);
        return !names.includes("broken");
      },
    }),
    false,
  );
  assert.equal(f.read("broken"), source);
  assert.equal(f.read("working"), source.replace(oldVersion, version));
  assert.deepEqual(calls, [["broken"], ["working"], ["working"]]);
});

test("restores grants when the final combined check fails", (t) => {
  const f = fixture(t, { one: source, two: source });
  assert.equal(
    f.run({
      bundles: [candidate("one"), candidate("two")],
      build: (names) => names.length === 1,
    }),
    false,
  );
  assert.equal(f.read("one"), source);
  assert.equal(f.read("two"), source);
});

test("restores an unverified edit and propagates an unexpected build error", (t) => {
  const f = fixture(t, { example: source });
  assert.throws(
    () =>
      f.run({
        bundles: [candidate("example")],
        build: () => {
          throw new Error("builder unavailable");
        },
      }),
    /builder unavailable/,
  );
  assert.equal(f.read("example"), source);
});

test("refuses computed or ambiguous declarations without editing them", (t) => {
  for (const invalid of [
    "{ dshEngines = runtime.version; }",
    '{ dshEngines = "stale"; }',
    `{ a = { dshEngines = "${oldVersion}"; }; b = { dshEngines = "${oldVersion}"; }; }`,
  ]) {
    const f = fixture(t, { example: invalid });
    assert.throws(() => f.run({ bundles: [candidate("example")] }));
    assert.equal(f.read("example"), invalid);
  }
});
