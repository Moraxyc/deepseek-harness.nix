import {
  DocsBody,
  DocsDescription,
  DocsPage,
  DocsTitle,
} from "fumadocs-ui/layouts/docs/page";
import { getMDXComponents } from "@/components/mdx";
import { docs, i18n, source, type Locale } from "@/lib/source";
import type { Route } from "./+types/docs";

const nonDefaultLocales = new Set<string>(
  i18n.languages.filter((lang) => lang !== i18n.defaultLanguage),
);

function parseRoutePath(splat: string | undefined): {
  locale: Locale;
  slugs: string[];
} {
  const segments = (splat ?? "").split("/").filter(Boolean);
  if (segments.length > 0 && nonDefaultLocales.has(segments[0])) {
    return {
      locale: segments[0] as Locale,
      slugs: segments.slice(1),
    };
  }
  return {
    locale: i18n.defaultLanguage,
    slugs: segments,
  };
}

export function loader({ params }: Route.LoaderArgs) {
  const { locale, slugs } = parseRoutePath(params["*"]);
  const page = source.getPage(slugs, locale);
  if (!page) throw new Response("Not found", { status: 404 });

  return {
    path: page.path,
    url: page.url,
  };
}

export default function Page({ loaderData }: Route.ComponentProps) {
  const page = docs.getPage(loaderData.path);
  if (!page) throw new Error(`Unknown documentation page: ${loaderData.path}`);

  const Mdx = page.body;

  return (
    <DocsPage
      toc={page.toc}
      tableOfContent={{ enabled: page.tableOfContents !== false }}
    >
      <title>{page.title}</title>
      <meta name="title" content={page.title} />
      {page.description && (
        <meta name="description" content={page.description} />
      )}
      <DocsTitle>{page.title}</DocsTitle>
      {page.description && (
        <DocsDescription>{page.description}</DocsDescription>
      )}
      <DocsBody>
        <Mdx components={getMDXComponents(loaderData.url)} />
      </DocsBody>
    </DocsPage>
  );
}
