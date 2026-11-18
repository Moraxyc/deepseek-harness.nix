#!/usr/bin/env node
// Raises each bundle's dshEngines grant to the pinned workspace version when
// its composition still boots: update-dsh-engines [BUNDLE]

import { type Candidate, capture, updateEngines } from "./engines.ts";

const BUNDLES_EXPR = `let
  f = import ./default.nix;
  system = builtins.currentSystem;
  packages = f.legacyPackages.\${system};
in {
  version = f.packages.\${system}.dsh-workspace.version;
  bundles = map (name: {
    inherit name;
    dshEngines = packages.bundles.\${name}.passthru.dshEngines or null;
  }) (builtins.attrNames packages.ciPackageAttrs.bundleCompositions);
}`;

const args = process.argv.slice(2);
if (args.length > 1) {
  process.stderr.write("usage: update-dsh-engines [BUNDLE]\n");
  process.exit(2);
}
const name = args[0];

const root = capture("git", ["rev-parse", "--show-toplevel"]).trim();
const metadata = JSON.parse(
  capture("nix", ["eval", "--impure", "--json", "--expr", BUNDLES_EXPR], root),
) as { version: string; bundles: Candidate[] };
if (name)
  metadata.bundles = metadata.bundles.filter((bundle) => bundle.name === name);
if (!updateEngines({ root, ...metadata })) process.exitCode = 1;
