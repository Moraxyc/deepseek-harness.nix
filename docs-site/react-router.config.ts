import type { Config } from "@react-router/dev/config";
import { cp, rename, rm, stat } from "node:fs/promises";
import * as path from "node:path";
import { fumadocsMdx } from "fumadocs-mdx/vite";
import { runnerImport } from "vite";

const BASENAME = "/deepseek-harness.nix/";

export default {
  appDirectory: "src/app",
  basename: BASENAME,
  ssr: false,
  async prerender({ getStaticPaths }) {
    const paths = new Set<string>(getStaticPaths());
    const { source } = (
      await runnerImport<typeof import("./src/lib/source")>(
        "./src/lib/source.ts",
        {
          plugins: [fumadocsMdx()],
          resolve: { tsconfigPaths: true },
        },
      )
    ).module;

    for (const page of source.getPages()) {
      paths.add(page.url);
    }

    return Array.from(paths);
  },
  async buildEnd({ reactRouterConfig }) {
    const clientDir = path.join(reactRouterConfig.buildDirectory, "client");
    const subDirName = BASENAME.replace(/^\/+|\/+$/g, "");
    const nestedDir = path.join(clientDir, subDirName);
    const spaFallback = path.join(clientDir, "index.html");

    const exists = await stat(nestedDir).catch(() => null);
    if (!exists?.isDirectory()) return;

    const fallbackExists = await stat(spaFallback).catch(() => null);
    if (fallbackExists?.isFile()) {
      await rename(spaFallback, path.join(clientDir, "404.html"));
    }

    await cp(nestedDir, clientDir, { recursive: true, force: true });
    await rm(nestedDir, { recursive: true, force: true });
  },
} satisfies Config;
