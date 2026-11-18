import { RootProvider } from "fumadocs-ui/provider/react-router";
import type { ReactNode } from "react";
import {
  isRouteErrorResponse,
  Links,
  Meta,
  Outlet,
  Scripts,
  ScrollRestoration,
  useLocation,
} from "react-router";
import SearchDialog from "@/components/search";
import type { Locale } from "@/lib/i18n";
import "@/styles/global.css";
import type { Route } from "./+types/root";
import NotFound from "./routes/not-found";

function resolveLocale(pathname: string): Locale {
  if (pathname === "/zh" || pathname.startsWith("/zh/")) return "zh";
  if (pathname === "/ja" || pathname.startsWith("/ja/")) return "ja";
  return "en";
}

export function Layout({ children }: { children: ReactNode }) {
  const { pathname } = useLocation();
  const locale = resolveLocale(pathname);

  return (
    <html lang={locale === "zh" ? "zh-CN" : locale} suppressHydrationWarning>
      <head>
        <meta charSet="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <Meta />
        <Links />
      </head>
      <body className="flex min-h-screen flex-col">
        <RootProvider
          i18n={{
            locale,
            defaultLanguage: "en",
            hideLocale: "default-locale",
            locales: [
              { locale: "en", name: "English" },
              { locale: "zh", name: "简体中文" },
              { locale: "ja", name: "日本語" },
            ],
          }}
          search={{ SearchDialog }}
        >
          {children}
        </RootProvider>
        <ScrollRestoration />
        <Scripts />
      </body>
    </html>
  );
}

export default function App() {
  return <Outlet />;
}

export function ErrorBoundary({ error }: Route.ErrorBoundaryProps) {
  if (isRouteErrorResponse(error) && error.status === 404) {
    return <NotFound />;
  }

  let message = "Error";
  let details = "An unexpected error occurred.";
  let stack: string | undefined;

  if (isRouteErrorResponse(error)) {
    details = error.statusText || details;
  } else if (import.meta.env.DEV && error instanceof Error) {
    details = error.message;
    stack = error.stack;
  }

  return (
    <main className="mx-auto w-full max-w-[900px] px-4 py-16">
      <h1 className="text-2xl font-semibold">{message}</h1>
      <p className="mt-2 text-fd-muted-foreground">{details}</p>
      {stack && (
        <pre className="mt-4 overflow-x-auto rounded-lg border p-4 text-sm">
          <code>{stack}</code>
        </pre>
      )}
    </main>
  );
}
