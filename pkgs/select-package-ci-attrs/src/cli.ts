#!/usr/bin/env node
// Prints the package attrs CI builds for the changes since BASE_REF, or every
// attr without BASE_REF: select-package-ci-attrs [BASE_REF]

import { spawnSync } from "node:child_process";
import {
  type Change,
  type PackageSet,
  classify,
  lockChanges,
  selectAttrs,
} from "./select.ts";

// The stdout of a command, or undefined when it fails.
function run(command: string, args: string[]): string | undefined {
  const result = spawnSync(command, args, {
    encoding: "utf8",
    maxBuffer: 64 * 1024 * 1024,
    stdio: ["ignore", "pipe", "ignore"],
  });
  if (result.error) throw result.error;
  return result.status === 0 ? result.stdout : undefined;
}

function capture(command: string, args: string[]): string {
  const result = spawnSync(command, args, {
    encoding: "utf8",
    maxBuffer: 64 * 1024 * 1024,
    stdio: ["ignore", "pipe", "inherit"],
  });
  if (result.error) throw result.error;
  if (result.status !== 0)
    throw new Error(
      `${command} ${args[0]} exited with status ${result.status}`,
    );
  return result.stdout;
}

const args = process.argv.slice(2);
if (args.length > 1) {
  process.stderr.write("usage: select-package-ci-attrs [BASE_REF]\n");
  process.exit(2);
}
const baseRef = args[0];

process.chdir(capture("git", ["rev-parse", "--show-toplevel"]).trim());
const system = capture("nix", [
  "eval",
  "--raw",
  "--impure",
  "--expr",
  "builtins.currentSystem",
]).trim();
const packageSet = JSON.parse(
  capture("nix", [
    "eval",
    "--json",
    `.#legacyPackages.${system}.ciPackageAttrs`,
  ]),
) as PackageSet;

let changes: Change[] = [{ kind: "global" }];
if (baseRef) {
  const lock = (ref: string) =>
    run("git", ["show", `${ref}:_sources/lock.json`]);
  changes = capture("git", ["diff", "--name-only", baseRef, "HEAD", "--", "."])
    .split("\n")
    .filter((file) => file !== "")
    .flatMap((file) =>
      classify(file, () => lockChanges(lock(baseRef), lock("HEAD"))),
    );
}
for (const attr of selectAttrs(changes, packageSet))
  process.stdout.write(`${attr}\n`);
