import { DocsLayout } from "fumadocs-ui/layouts/docs";
import { DocsPage, type DocsPageProps } from "fumadocs-ui/layouts/docs/page";
import type { AstroProviderProps } from "fumadocs-core/framework/astro";
import type { Root } from "fumadocs-core/page-tree";
import { navigate } from "astro:transitions/client";
import { RootProvider } from "fumadocs-ui/provider/astro";
import type { ReactNode } from "react";
import SearchDialog from "./search";
import type { Locale } from "@/lib/source";

interface Props {
  tree: Root;
  children: ReactNode;
  pathname: string;
  params: AstroProviderProps["params"];
  page?: DocsPageProps;
  locale: Locale;
  localeUrls: Partial<Record<Locale, string>>;
  homeUrls: Partial<Record<Locale, string>>;
}

export function Docs({
  tree,
  children,
  pathname,
  params,
  page,
  locale,
  localeUrls,
  homeUrls,
}: Props) {
  return (
    <RootProvider
      pathname={pathname}
      params={params}
      navigate={navigate}
      i18n={{
        locale,
        locales: [
          { locale: "en", name: "English" },
          { locale: "zh", name: "简体中文" },
        ],
        onLocaleChange: (nextLocale) => {
          const url = localeUrls[nextLocale as Locale];
          if (url) void navigate(url.endsWith("/") ? url : `${url}/`);
        },
      }}
      search={{ SearchDialog }}
    >
      <DocsLayout
        tree={tree}
        githubUrl="https://github.com/moraxyc/deepseek-harness.nix"
        nav={{
          title: "DSH Nix",
          url: homeUrls[locale] ?? "/",
        }}
      >
        <DocsPage {...page}>{children}</DocsPage>
      </DocsLayout>
    </RootProvider>
  );
}
