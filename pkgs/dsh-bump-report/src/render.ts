// Renders a bump report as Markdown.

import type { BundleResult, Report, SetDiff } from "./compare.ts";

function list<T>(
  items: T[],
  render: (item: T) => string = (item) => `\`${item}\``,
): string {
  return items.length
    ? items.map((item) => `- ${render(item)}`).join("\n")
    : "- none";
}

const signed = (change: SetDiff) => [
  ...change.added.map((item) => `+ ${item}`),
  ...change.removed.map((item) => `- ${item}`),
];

function bundleGate(bundle: BundleResult, evaluated: boolean): string {
  if (!bundle.gate.length) return evaluated ? "ok" : "n/a";
  const unmet = bundle.gate.map((g) => g.unmet.length).join("+");
  return bundle.source === "built"
    ? `rejected (${unmet} unmet)`
    : `likely rejected (${unmet} unmet)`;
}

export function renderMarkdown(report: Report): string {
  const { packages: pkgs, buildInputs: build } = report;
  const out = [
    `# dsh-workspace ${report.versions.old} -> ${report.versions.new}`,
    "",
    "## Actions",
    "",
    list(report.actions, (a) => a),
    "",
    "## Workspace packages",
    "",
    `Added (${pkgs.added.length}):`,
    list(pkgs.added),
    "",
    `Removed (${pkgs.removed.length}):`,
    list(pkgs.removed),
    "",
    "Moved:",
    list(pkgs.moved, (m) => `\`${m.name}\`: ${m.from} -> ${m.to}`),
    "",
    "Removed exports:",
    list(pkgs.removedExports, (e) => `\`${e.name}\`: ${e.subpaths.join(", ")}`),
    "",
    "Install scripts:",
    list(pkgs.lifecycle, (l) => `\`${l.name}\`: ${JSON.stringify(l.after)}`),
    "",
    "New native code:",
    list(pkgs.native, (n) => `\`${n.name}\` (${n.dir})`),
    "",
    "bin changes:",
    list(pkgs.bin, (b) => `\`${b.name}\``),
    "",
    "## Official bundles",
    "",
    "Bundle manifests:",
    list(pkgs.bundle, (b) => `\`${b.name}\` ${b.change}`),
  ];
  for (const [name, change] of Object.entries(report.officialLists))
    out.push(
      "",
      `${name}:`,
      list(signed(change), (n) => n),
    );
  out.push(
    "",
    `Rows removed (${report.rows.removed.length}):`,
    list(report.rows.removed),
    "",
    `Rows added (${report.rows.added.length}):`,
    list(report.rows.added),
    "",
    "## Build inputs",
    "",
    "Root build scripts:",
    list(build.rootScripts),
    "",
    "Root fields:",
    list(build.rootFields),
    "",
    "pnpm-workspace.yaml keys:",
    list(build.workspaceKeys),
    "",
    "Workspace globs:",
    list(signed(build.workspaceGlobs), (g) => g),
    "",
    "Patched dependencies (patches/):",
    list(build.patches),
    "",
    "Tracked files:",
    list(build.files),
    "",
    "## pkgs/dsh-workspace references",
    "",
    list(
      report.localPatchTargets.filter(
        (t) => t.status !== "unchanged" && t.status !== "present",
      ),
      (t) => `${t.status}: \`${t.target}\` (${t.owner})`,
    ),
    "",
    "## Repository references",
    "",
    list(report.repoRefs, (r) => `${r.status}: \`${r.ref}\` (${r.file})`),
    "",
    "## Bundles",
    "",
  );
  if (!report.bundles.length) out.push("- not evaluated");
  else {
    out.push(
      "Source rows read the fetched source without this repository's patches; build the bundle for exact results.",
      "",
      "| bundle | version | source | overrideDshEngineVersion | gate | stale refs | stale rows |",
      "| --- | --- | --- | --- | --- | --- | --- |",
    );
    for (const b of report.bundles)
      out.push(
        `| ${b.attr} | ${b.version} | ${b.source} | ${b.overrideDshEngineVersion ? "true" : ""} | ${bundleGate(b, report.gateEvaluated)} | ${b.refs.map((r) => r.ref).join("<br>")} | ${b.staleRows.map((r) => r.id).join("<br>")} |`,
      );
  }
  return `${out.join("\n")}\n`;
}
