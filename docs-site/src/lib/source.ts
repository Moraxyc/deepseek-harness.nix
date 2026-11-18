import type { StructuredData } from "fumadocs-core/mdx-plugins";
import { structure } from "fumadocs-core/mdx-plugins";
import { loader } from "fumadocs-core/source";
import { pageSchema } from "fumadocs-core/source/schema";
import { defineDocs } from "fumadocs-mdx/macro";
import { z } from "zod";
import { catalog } from "@/data/catalog";
import { i18n, type Locale } from "./i18n";

export { i18n, type Locale };

export const docs = defineDocs({
  dir: "src/content/docs",
  docs: {
    async: false,
    schema: pageSchema.extend({
      tableOfContents: z.boolean().optional(),
    }),
  },
});

export const source = loader({
  source: docs.toFumadocsSource(),
  baseUrl: "/",
  i18n,
});

const catalogSlug = "catalog";

/** Includes generated catalog entries absent from the page's MDX body. */
export function getStructuredData(
  page: NonNullable<ReturnType<typeof source.getPage>>,
): StructuredData {
  const body = page.data.structuredData;
  if (page.slugs[page.slugs.length - 1] !== catalogSlug) return body;

  const locale = (page.locale ?? i18n.defaultLanguage) as Locale;
  return {
    headings: body.headings,
    contents: [
      ...body.contents,
      ...structure(catalogParagraphs(locale).join("\n\n")).contents,
    ],
  };
}

function catalogParagraphs(locale: Locale): string[] {
  const text =
    locale === "ja"
      ? { defaultProfile: "デフォルトプロファイル", bundles: "バンドル" }
      : { defaultProfile: "default profile", bundles: "Bundles" };
  const descriptionOf = (item: {
    description: string | null;
    descriptionZh: string | null;
    descriptionJa: string | null;
  }): string =>
    (locale === "zh"
      ? (item.descriptionZh ?? item.description)
      : locale === "ja"
        ? (item.descriptionJa ?? item.description)
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
            : `${text.defaultProfile} ${preset.defaultProfile}`,
        ]
          .filter((part) => part !== "")
          .join(", "),
        descriptionOf(preset),
        preset.bundles.length === 0
          ? ""
          : ` ${text.bundles}: ${preset.bundles.join(" ")}`,
      ),
    ),
  ];
}
