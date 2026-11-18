#!/usr/bin/env node
// usage: generate-optional-bundles SOURCE_ROOT OUTPUT

import fs from "node:fs";
import path from "node:path";
import { GenerateError, optionalBundles } from "./optional-bundles.ts";

const log = (message: string) =>
  process.stderr.write(`generate-optional-bundles: ${message}\n`);

const args = process.argv.slice(2);
const [src, dest] = args;
if (src === undefined || dest === undefined || args.length > 2) {
  process.stderr.write(
    "usage: generate-optional-bundles <upstream-source-root> <output>\n",
  );
  process.exit(2);
}

try {
  const bundles = optionalBundles(src, log);
  const content = `${JSON.stringify(bundles, null, 2)}\n`;
  const members = Object.keys(bundles).length;
  if (fs.existsSync(dest) && fs.readFileSync(dest, "utf8") === content) {
    console.log(`optional bundles: ${members} members, unchanged`);
  } else {
    fs.mkdirSync(path.dirname(dest), { recursive: true });
    fs.writeFileSync(dest, content);
    console.log(`optional bundles: ${members} members written to ${dest}`);
  }
} catch (error) {
  if (!(error instanceof GenerateError)) throw error;
  log(error.message);
  process.exit(1);
}
