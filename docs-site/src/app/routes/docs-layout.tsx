import { useFumadocsLoader } from "fumadocs-core/source/client";
import { DocsLayout } from "fumadocs-ui/layouts/docs";
import { Outlet, type ShouldRevalidateFunctionArgs } from "react-router";
import { i18n, source, type Locale } from "@/lib/source";
import type { Route } from "./+types/docs-layout";

const BASE_PATH = import.meta.env.BASE_URL.replace(/\/+$/, "");
const nonDefaultLocales = new Set<string>(
  i18n.languages.filter((lang) => lang !== i18n.defaultLanguage),
);

function localeFromUrl(rawUrl: string): Locale {
  let pathname = new URL(rawUrl, "https://dsh.invalid").pathname;
  if (BASE_PATH && pathname.startsWith(BASE_PATH)) {
    pathname = pathname.slice(BASE_PATH.length) || "/";
  }
  const first = pathname.split("/").filter(Boolean)[0];
  return first && nonDefaultLocales.has(first)
    ? (first as Locale)
    : i18n.defaultLanguage;
}

export async function loader({ request }: Route.LoaderArgs) {
  const locale = localeFromUrl(request.url);
  return {
    locale,
    pageTree: await source.serializePageTree(source.getPageTree(locale)),
  };
}

export function shouldRevalidate({
  currentUrl,
  nextUrl,
  defaultShouldRevalidate,
}: ShouldRevalidateFunctionArgs) {
  if (localeFromUrl(currentUrl.pathname) !== localeFromUrl(nextUrl.pathname)) {
    return true;
  }
  return defaultShouldRevalidate && false;
}

export default function DocsShell({ loaderData }: Route.ComponentProps) {
  const { pageTree, locale } = useFumadocsLoader(loaderData);

  return (
    <DocsLayout
      tree={pageTree}
      githubUrl="https://github.com/moraxyc/deepseek-harness.nix"
      nav={{
        title: "DSH Nix",
        url: locale === i18n.defaultLanguage ? "/" : `/${locale}`,
      }}
    >
      <Outlet />
    </DocsLayout>
  );
}
