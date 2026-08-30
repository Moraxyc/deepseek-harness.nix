import { type CollectionEntry, getCollection } from "astro:content";
import { defineI18n } from "fumadocs-core/i18n";
import { structure, type StructuredData } from "fumadocs-core/mdx-plugins";
import { loader, type StaticSource } from "fumadocs-core/source";
import * as path from "node:path";

export type Locale = "en" | "zh";

export const i18n = defineI18n<Locale>({
  languages: ["en", "zh"],
  defaultLanguage: "en",
  parser: "dir",
  hideLocale: "default-locale",
  fallbackLanguage: null,
});

const basePath = import.meta.env.BASE_URL.split("/").filter(Boolean);

export const source = loader({
  source: await createSource(),
  baseUrl: import.meta.env.BASE_URL.replace(/\/$/, ""),
  i18n,
  url: (slugs, locale) => {
    const localePath = locale === i18n.defaultLanguage ? [] : [locale];
    return `/${[...basePath, ...localePath, ...slugs].join("/")}`;
  },
});

export function getStructuredData(
  entry: CollectionEntry<"docs">,
): StructuredData {
  return structure(entry.body ?? "");
}

async function createSource() {
  const out: StaticSource<{
    metaData: CollectionEntry<"meta">["data"];
    pageData: CollectionEntry<"docs">["data"] & {
      _raw: CollectionEntry<"docs">;
    };
  }> = {
    files: [],
  };

  for (const page of await getCollection("docs")) {
    const virtualPath = path.relative("src/content/docs", page.filePath!);

    out.files.push({
      type: "page",
      path: virtualPath,
      data: {
        ...page.data,
        _raw: page,
      },
    });
  }

  for (const meta of await getCollection("meta")) {
    const virtualPath = path.relative("src/content/docs", meta.filePath!);

    out.files.push({
      type: "meta",
      path: virtualPath,
      data: meta.data,
    });
  }

  return out;
}
