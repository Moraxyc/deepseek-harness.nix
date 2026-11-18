#!/usr/bin/env node
// Resolves the upstream trees, the runtime and the bundle set with nix, then
// prints the bump report.

import { spawnSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import { parseArgs } from "node:util";
import { type Evaluate, buildReport } from "./compare.ts";
import type { BundleEntry } from "./inventory.ts";
import { renderMarkdown } from "./render.ts";

const USAGE = `usage: dsh-bump-report [--json] [--strict] [--no-bundles] [--fetch-sources]
                       [--old SRC] [--runtime INSTALLABLE] NEW

NEW and SRC are an upstream version (0.2.2-alpha.3), a tag (dsh-v0.2.2-alpha.3),
or a source directory. SRC defaults to the pinned dsh-workspace source.
Bundle compatibility is evaluated with dsh-app-boot from INSTALLABLE
(default .#dsh-runtime) against built bundles, or their sources when present in
the store. --fetch-sources downloads the missing sources first. --strict exits
nonzero when the report lists actions.
`;

// The CI bundle set: buildable on this platform, not removed or broken.
const BUNDLES_EXPR = `packages:
  map (
    attr:
    let
      bundle = packages.bundles.\${attr};
      src = bundle.src or null;
    in
    {
      inherit attr;
      version = bundle.version or "";
      out = bundle.outPath;
      src = if src == null then null else src.outPath;
      srcDrv = if src == null then null else src.drvPath;
      dshEngines = bundle.passthru.dshEngines or null;
      workspace = (src.pname or null) == "dsh-workspace";
    }
  ) (builtins.attrNames packages.ciPackageAttrs.bundles)`;

function log(message: string): void {
  process.stderr.write(`dsh-bump-report: ${message}\n`);
}

// The trimmed stdout of a command that must succeed.
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
  return result.stdout.trim();
}

function resolveSource(ref: string): string {
  if (fs.existsSync(ref) && fs.statSync(ref).isDirectory())
    return fs.realpathSync(ref);
  const tag = ref.startsWith("dsh-v") ? ref : `dsh-v${ref}`;
  const { storePath } = JSON.parse(
    capture("nix", [
      "flake",
      "prefetch",
      "--json",
      `github:deepseek-ai/deepseek-harness/${tag}`,
    ]),
  ) as { storePath: string };
  return storePath;
}

const buildOut = (installable: string) =>
  capture("nix", ["build", "--no-link", "--print-out-paths", installable]);

function bundleEntries(fetchSources: boolean): BundleEntry[] {
  const system = capture("nix", [
    "eval",
    "--raw",
    "--impure",
    "--expr",
    "builtins.currentSystem",
  ]);
  const entries = JSON.parse(
    capture("nix", [
      "eval",
      "--json",
      `.#legacyPackages.${system}`,
      "--apply",
      BUNDLES_EXPR,
    ]),
  ) as BundleEntry[];
  // Bundles without a local build fall back to their source.
  const missing = entries
    .filter(
      (entry) =>
        !entry.workspace &&
        entry.srcDrv !== null &&
        !fs.existsSync(entry.out) &&
        !(entry.src && fs.existsSync(entry.src)),
    )
    .map((entry) => `${entry.srcDrv}^out`);
  if (missing.length && fetchSources) {
    log(`fetching ${missing.length} bundle sources`);
    const result = spawnSync("nix", ["build", "--no-link", "-L", ...missing], {
      stdio: ["ignore", 2, 2],
    });
    if (result.status !== 0) throw new Error("fetching bundle sources failed");
  } else if (missing.length) {
    log(
      `${missing.length} bundles are neither built nor fetched; pass --fetch-sources to include them`,
    );
  }
  return entries;
}

let parsed;
try {
  parsed = parseArgs({
    allowPositionals: true,
    options: {
      json: { type: "boolean", default: false },
      strict: { type: "boolean", default: false },
      "no-bundles": { type: "boolean", default: false },
      "fetch-sources": { type: "boolean", default: false },
      old: { type: "string" },
      runtime: { type: "string", default: ".#dsh-runtime" },
      help: { type: "boolean", short: "h", default: false },
    },
  });
} catch {
  parsed = null;
}
if (!parsed || parsed.values.help || parsed.positionals.length !== 1) {
  process.stderr.write(USAGE);
  process.exit(2);
}
const { values: args, positionals } = parsed;
const newRef = positionals[0] as string;

const repo = capture("git", ["rev-parse", "--show-toplevel"]);
process.chdir(repo);

log("resolving upstream sources");
const oldRoot = args.old
  ? resolveSource(args.old)
  : buildOut(".#dsh-workspace.src");
const newRoot = resolveSource(newRef);
log(`old ${oldRoot}`);
log(`new ${newRoot}`);

let evaluate: Evaluate | null = null;
let bundles: BundleEntry[] = [];
if (!args["no-bundles"]) {
  log("resolving the runtime");
  const appBoot = path.join(
    buildOut(args.runtime),
    "node_modules/@deepseek-ai/dsh-app-boot/lib/index.js",
  );
  ({ evaluatePluginCompatibility: evaluate } = (await import(appBoot)) as {
    evaluatePluginCompatibility: Evaluate;
  });
  log("evaluating bundles");
  bundles = bundleEntries(args["fetch-sources"]);
  log("writing the report");
}

const report = buildReport({
  oldRoot,
  newRoot,
  repo,
  bundles,
  evaluate,
  progress: log,
});
process.stdout.write(
  args.json ? `${JSON.stringify(report, null, 2)}\n` : renderMarkdown(report),
);
if (args.strict && report.actions.length) process.exitCode = 1;
