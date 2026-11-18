// Reads the optional bundle set from an upstream source tree: the members of
// OPTIONAL_BUNDLES in packages/util/official-bundles/src/bundles.ts, with the
// metadata lib/dsh-optional-bundles.nix needs to package each one.

import fs from "node:fs";
import path from "node:path";

export const BUNDLES_TS = "packages/util/official-bundles/src/bundles.ts";
export const CLI_MANIFEST = "apps/cli/package.json";

const BLANK = /^\s*(\/\/.*)?$/;
const ENTRY = /^\s*["'](@deepseek-ai\/[a-z0-9][a-z0-9-]*)["'],?\s*(\/\/.*)?$/;
const TEMPLATE_BUNDLE = /["'](@deepseek-ai\/[^"']*)["']/g;
const TERMINAL_CONTROLLER = "@deepseek-ai/dsh-api-terminal-controller";

export interface OptionalBundle {
  attr: string;
  pname: string;
  description: string;
  descriptionZh: string;
  descriptionJa: string;
  requiresWeb: boolean;
  platforms: unknown[];
}

interface Manifest {
  name?: unknown;
  description?: unknown;
  dependencies?: Record<string, string>;
  peerDependencies?: Record<string, string>;
  dsh?: {
    bundle?: { patch?: unknown; platforms?: unknown[] };
    client?: { platform?: unknown };
  };
}

export class GenerateError extends Error {}

function fail(message: string): never {
  throw new GenerateError(message);
}

const readJson = <T>(file: string): T =>
  JSON.parse(fs.readFileSync(file, "utf8")) as T;

const sortedUnique = (values: Iterable<string>): string[] =>
  [...new Set(values)].sort();

// The lines between `export const NAME` and the first line matching CLOSE.
function declarationBody(
  lines: string[],
  name: string,
  close: RegExp,
): string[] | undefined {
  const start = new RegExp(`^export const ${name}[^A-Za-z0-9_$]`);
  const first = lines.findIndex((line) => start.test(line));
  if (first === -1) return undefined;
  const end = lines.findIndex(
    (line, index) => index > first && close.test(line),
  );
  return end === -1 ? undefined : lines.slice(first + 1, end);
}

export function optionalBundleNames(source: string): string[] {
  const lines = source.split("\n");
  const body =
    declarationBody(lines, "OPTIONAL_BUNDLES", /^]/) ??
    fail("OPTIONAL_BUNDLES is missing or unterminated");
  const names = body.flatMap((line) => {
    if (BLANK.test(line)) return [];
    const match = ENTRY.exec(line);
    return match?.[1] ?? fail(`unexpected OPTIONAL_BUNDLES line: ${line}`);
  });
  if (names.length === 0) fail("OPTIONAL_BUNDLES is empty");
  return sortedUnique(names);
}

export function profileTemplateBundles(source: string): Set<string> {
  const lines = source.split("\n");
  const body =
    declarationBody(lines, "PROFILE_TEMPLATES", /^}/) ??
    fail("PROFILE_TEMPLATES is missing or unterminated");
  const names = body.flatMap((line) =>
    [...line.matchAll(TEMPLATE_BUNDLE)].map((match) => match[1] as string),
  );
  if (names.length === 0) fail("PROFILE_TEMPLATES is empty or unparsable");
  return new Set(names);
}

// Manifests at packages/*/*/package.json, keyed by package name.
function workspaceManifests(
  src: string,
): Map<string, { dir: string; manifest: Manifest }> {
  const packages = new Map<string, { dir: string; manifest: Manifest }>();
  const children = (dir: string) =>
    fs
      .readdirSync(dir, { withFileTypes: true })
      .filter((entry) => entry.isDirectory())
      .map((entry) => path.join(dir, entry.name))
      .sort();
  for (const dir of children(path.join(src, "packages")).flatMap(children)) {
    const file = path.join(dir, "package.json");
    if (!fs.existsSync(file)) continue;
    const manifest = readJson<Manifest>(file);
    if (typeof manifest.name !== "string" || manifest.name === "") continue;
    packages.set(manifest.name, { dir, manifest });
  }
  return packages;
}

const needsWebClient = (manifest: Manifest) =>
  manifest.dsh?.client?.platform === "web" ||
  Object.hasOwn(manifest.peerDependencies ?? {}, TERMINAL_CONTROLLER);

// A locale file's meta.description, or undefined when it has none.
function localeDescription(dir: string, locale: string): string | undefined {
  try {
    const { meta } = readJson<{ meta?: { description?: unknown } }>(
      path.join(dir, "locale", `${locale}.json`),
    );
    const description = meta?.description;
    return typeof description === "string" && description !== ""
      ? description
      : undefined;
  } catch {
    return undefined;
  }
}

export function optionalBundles(
  src: string,
  warn: (message: string) => void = () => {},
): Record<string, OptionalBundle> {
  const bundlesTs = path.join(src, BUNDLES_TS);
  const cliManifest = path.join(src, CLI_MANIFEST);
  for (const required of [bundlesTs, cliManifest])
    if (!fs.existsSync(required) || !fs.statSync(required).isFile())
      fail(`missing ${required}; is this an upstream source tree?`);

  const source = fs.readFileSync(bundlesTs, "utf8");
  const names = optionalBundleNames(source);
  const templates = profileTemplateBundles(source);
  const installed = readJson<Manifest>(cliManifest).dependencies ?? {};
  const packages = workspaceManifests(src);

  const result: Record<string, OptionalBundle> = {};
  for (const name of names) {
    const entry = packages.get(name);
    const bundle = entry?.manifest.dsh?.bundle;
    if (!entry || bundle?.patch == null || bundle.patch === false)
      fail(`${name} is not a workspace bundle`);
    const { dir, manifest } = entry;
    if (!Object.hasOwn(installed, name))
      fail(`${name} is not an installation dependency`);
    if (templates.has(name))
      fail(`${name} is selected by a shipped profile template`);

    const pname = name.slice(name.lastIndexOf("/") + 1);
    const description =
      localeDescription(dir, "en") ??
      (typeof manifest.description === "string" && manifest.description !== ""
        ? manifest.description
        : fail(`${name} has no description`));
    const translated = (locale: string, language: string) => {
      const text = localeDescription(dir, locale);
      if (text !== undefined) return text;
      warn(`${name} has no ${language} description; using English`);
      return description;
    };
    const descriptionZh = translated("zh", "Chinese");
    const descriptionJa = translated("ja", "Japanese");
    // A workspace dependency that needs the web client brings it in too.
    const requiresWeb =
      needsWebClient(manifest) ||
      Object.keys(manifest.dependencies ?? {}).some((dependency) => {
        const dependencyManifest = packages.get(dependency)?.manifest;
        return (
          dependencyManifest !== undefined && needsWebClient(dependencyManifest)
        );
      });

    result[name] = {
      attr: pname.replace(/^dsh-/, ""),
      pname,
      description,
      descriptionZh,
      descriptionJa,
      requiresWeb,
      platforms: bundle.platforms ?? [],
    };
  }
  return result;
}
