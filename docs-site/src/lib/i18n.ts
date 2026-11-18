import { defineI18n } from "fumadocs-core/i18n";

export type Locale = "en" | "zh" | "ja";

export const i18n = defineI18n<Locale>({
  languages: ["en", "zh", "ja"],
  defaultLanguage: "en",
  parser: "dir",
  hideLocale: "default-locale",
  fallbackLanguage: null,
});
