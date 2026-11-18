import defaultMdxComponents from "fumadocs-ui/mdx";
import type { MDXComponents } from "mdx/types";
import type { AnchorHTMLAttributes } from "react";
import { Link } from "react-router";

const EXTERNAL_SCHEME = /^(?:[a-z][a-z0-9+.-]*:|\/\/)/i;

function resolveDocLink(href: string, pageUrl: string): string {
  const baseDir = pageUrl === "/" ? "/" : `${pageUrl.replace(/\/+$/, "")}/`;
  const resolved = new URL(href, `https://dsh.invalid${baseDir}`);
  const pathname =
    resolved.pathname.length > 1
      ? resolved.pathname.replace(/\/+$/, "")
      : resolved.pathname;
  return `${pathname}${resolved.search}${resolved.hash}`;
}

export function getMDXComponents(
  pageUrl = "/",
  components?: MDXComponents,
): MDXComponents {
  function Anchor({
    href,
    children,
    ...props
  }: AnchorHTMLAttributes<HTMLAnchorElement>) {
    if (!href || href.startsWith("#") || EXTERNAL_SCHEME.test(href)) {
      return (
        <a href={href} {...props}>
          {children}
        </a>
      );
    }

    return (
      <Link to={resolveDocLink(href, pageUrl)} prefetch="intent" {...props}>
        {children}
      </Link>
    );
  }

  return {
    ...defaultMdxComponents,
    a: Anchor,
    HomeLink: Anchor,
    ...components,
  };
}
