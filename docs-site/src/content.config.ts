import { defineCollection } from "astro:content";
import { glob } from "astro/loaders";
import { z } from "astro:content";

const docs = defineCollection({
  loader: glob({ pattern: "**/*.mdx", base: "./src/content/docs" }),
  schema: z.object({
    title: z.string(),
    description: z.string().optional(),
    icon: z.string().optional(),
    tableOfContents: z.boolean().optional(),
  }),
});

const meta = defineCollection({
  loader: glob({ pattern: "**/*.{json,yaml}", base: "./src/content/docs" }),
  schema: z.object({
    title: z.string().optional(),
    description: z.string().optional(),
    pages: z.array(z.string()).optional(),
    icon: z.string().optional(),
    root: z.boolean().optional(),
    defaultOpen: z.boolean().optional(),
    collapsible: z.boolean().optional(),
    pagesIndex: z.string().optional(),
  }),
});

export const collections = {
  docs,
  meta,
};
