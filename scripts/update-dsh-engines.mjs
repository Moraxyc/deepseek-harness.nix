import { spawnSync } from "node:child_process";
import { readFileSync, writeFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

function capture(command, args, cwd) {
  const result = spawnSync(command, args, {
    cwd,
    encoding: "utf8",
    maxBuffer: 16 * 1024 * 1024,
    timeout: 5 * 60_000,
    stdio: ["ignore", "pipe", "inherit"],
  });
  if (result.error) throw result.error;
  if (result.status !== 0)
    throw new Error(`${command} exited with status ${result.status}`);
  return result.stdout;
}

function buildCompositions(root, names) {
  const result = spawnSync(
    "nix",
    [
      "build",
      "--no-link",
      "--print-build-logs",
      ...names.map((name) => `.#bundleCompositions.${name}`),
    ],
    { cwd: root, stdio: ["ignore", 2, 2], timeout: 30 * 60_000 },
  );
  if (result.error) throw result.error;
  if (result.signal)
    throw new Error(`nix build terminated by ${result.signal}`);
  return result.status === 0;
}

export function updateEngines({
  root,
  version,
  bundles,
  build = (names) => buildCompositions(root, names),
  report = console.log,
}) {
  if (!/^\d+\.\d+\.\d+(?:-[\w.-]+)?(?:\+[\w.-]+)?$/.test(version))
    throw new Error(`Invalid workspace version: ${version}`);

  report(`## dshEngines compatibility / 兼容性 (${version})\n`);
  report("| bundle | result / 结果 |\n| --- | --- |");
  const accepted = [];
  let failed = false;
  for (const { name, dshEngines } of bundles) {
    if (dshEngines == null || dshEngines === version) continue;
    if (!/^[\w-]+$/.test(name)) throw new Error(`Invalid bundle name: ${name}`);
    const file = path.join(root, "pkgs/bundles", name, "package.nix");
    const matches = JSON.parse(
      capture(
        "ast-grep",
        [
          "run",
          "--lang",
          "nix",
          "--pattern",
          "{ dshEngines = $VALUE; }",
          "--selector",
          "binding",
          "--json=compact",
          file,
        ],
        root,
      ),
    );
    const value = matches[0]?.metaVariables.single.VALUE;
    if (matches.length !== 1 || value?.text !== JSON.stringify(dshEngines))
      throw new Error(`${file}: expected one literal dshEngines declaration`);

    const original = readFileSync(file);
    const { start, end } = value.range.byteOffset;
    writeFileSync(
      file,
      Buffer.concat([
        original.subarray(0, start),
        Buffer.from(JSON.stringify(version)),
        original.subarray(end),
      ]),
    );
    let passed = false;
    try {
      passed = build([name]);
    } finally {
      if (!passed) writeFileSync(file, original);
    }
    if (passed) accepted.push({ name, file, original });
    else failed = true;
    report(
      `| ${name} | ${passed ? "passed / 通过" : "failed; restored / 失败，已还原"} |`,
    );
  }

  // Recheck accepted grants together after failed candidates have been restored.
  if (accepted.length > 0) {
    let passed = false;
    try {
      passed = build(accepted.map(({ name }) => name));
    } finally {
      if (!passed) {
        for (const { file, original } of accepted)
          writeFileSync(file, original);
      }
    }
    if (!passed) {
      failed = true;
      report(
        "\nFinal composition check failed; grants restored. / 最终组合检查失败，已还原授权。",
      );
    }
  } else if (!failed) {
    report("| — | no changes / 无需更新 |");
  }
  return !failed;
}

function main() {
  const root = fileURLToPath(new URL("../", import.meta.url));
  const name = process.argv[2];
  if (process.argv.length > 3)
    throw new Error("Expected at most one bundle name");
  const metadata = JSON.parse(
    capture(
      "nix",
      [
        "eval",
        "--impure",
        "--json",
        "--expr",
        `let
          f = import ./default.nix;
          system = builtins.currentSystem;
          packages = f.legacyPackages.\${system};
        in {
          version = f.packages.\${system}.dsh-workspace.version;
          bundles = map (name: {
            inherit name;
            dshEngines = packages.bundles.\${name}.passthru.dshEngines or null;
          }) (builtins.attrNames packages.ciPackageAttrs.bundleCompositions);
        }`,
      ],
      root,
    ),
  );
  if (name)
    metadata.bundles = metadata.bundles.filter(
      (bundle) => bundle.name === name,
    );
  if (!updateEngines({ root, ...metadata })) process.exitCode = 1;
}

if (
  process.argv[1] &&
  import.meta.url === pathToFileURL(process.argv[1]).href
) {
  main();
}
