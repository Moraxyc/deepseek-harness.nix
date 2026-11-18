import { HomeLayout } from "fumadocs-ui/layouts/home";
import { Link } from "react-router";

export function meta() {
  return [{ title: "Page Not Found — DSH Nix" }];
}

export default function NotFound() {
  return (
    <HomeLayout
      githubUrl="https://github.com/moraxyc/deepseek-harness.nix"
      nav={{ title: "DSH Nix", url: "/" }}
    >
      <main className="mx-auto flex w-full max-w-[900px] flex-1 flex-col items-center justify-center px-4 py-16 text-center">
        <h1 className="text-2xl font-semibold">Page Not Found</h1>
        <p className="mt-2 mb-6 text-fd-muted-foreground">
          The requested documentation page does not exist.
        </p>
        <Link
          to="/"
          className="rounded-lg border px-4 py-2 text-sm font-medium transition-colors hover:bg-fd-accent hover:text-fd-accent-foreground"
        >
          Back to Home
        </Link>
      </main>
    </HomeLayout>
  );
}
