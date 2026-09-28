import type { APIRoute } from "astro";
import { createFromSource } from "fumadocs-core/search/server";
import { getStructuredData, i18n, source, type Locale } from "@/lib/source";

const server = createFromSource(source, {
  buildIndex(page) {
    return {
      id: page.data._raw.id,
      title: page.data.title,
      description: page.data.description,
      structuredData: getStructuredData(
        page.data._raw,
        (page.locale ?? i18n.defaultLanguage) as Locale,
      ),
      url: page.url,
    };
  },
});

export const GET: APIRoute = () => server.staticGET();
