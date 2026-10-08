import { type CollectionEntry, getCollection } from "astro:content";
import { defineI18n } from "fumadocs-core/i18n";
import { structure, type StructuredData } from "fumadocs-core/mdx-plugins";
import { loader, type StaticSource } from "fumadocs-core/source";
import * as path from "node:path";
import { catalog } from "@/data/catalog";

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

const catalogSlug = "catalog";

/** Includes generated catalog entries absent from the page's MDX body. */
export function getStructuredData(
  entry: CollectionEntry<"docs">,
  locale: Locale,
): StructuredData {
  const body = structure(entry.body ?? "");
  if (entry.id.split("/").pop() !== catalogSlug) return body;
  return {
    headings: body.headings,
    contents: [
      ...body.contents,
      ...structure(catalogParagraphs(locale).join("\n\n")).contents,
    ],
  };
}

function catalogParagraphs(locale: Locale): string[] {
  const descriptionOf = (item: {
    description: string | null;
    descriptionZh: string | null;
  }): string =>
    (locale === "zh"
      ? (item.descriptionZh ?? item.description)
      : item.description) ?? "";

  const row = (
    identity: string,
    detail: string,
    description: string,
    extra = "",
  ): string =>
    `${identity} (${detail})${description === "" ? "" : `: ${description}`}${extra}`;

  return [
    ...catalog.bundles.map((bundle) =>
      row(
        `bundles.${bundle.name}`,
        [bundle.package, bundle.version]
          .filter((part) => part !== null)
          .join(" "),
        descriptionOf(bundle),
      ),
    ),
    ...catalog.presets.map((preset) =>
      row(
        `presets.${preset.name}`,
        [
          preset.package,
          preset.defaultProfile === null
            ? ""
            : `default profile ${preset.defaultProfile}`,
        ]
          .filter((part) => part !== "")
          .join(", "),
        descriptionOf(preset),
        preset.bundles.length === 0
          ? ""
          : ` Bundles: ${preset.bundles.join(" ")}`,
      ),
    ),
  ];
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
