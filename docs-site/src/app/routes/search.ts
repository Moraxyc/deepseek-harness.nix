import { createFromSource } from "fumadocs-core/search/server";
import { getStructuredData, source } from "@/lib/source";

const server = createFromSource(source, {
  buildIndex(page) {
    return {
      id: page.path,
      title: page.data.title,
      description: page.data.description,
      structuredData: getStructuredData(page),
      url: page.url,
    };
  },
});

export function loader() {
  return server.staticGET();
}
