import {
  index,
  layout,
  route,
  type RouteConfig,
} from "@react-router/dev/routes";

export default [
  route("api/search", "routes/search.ts"),
  layout("routes/docs-layout.tsx", [
    index("routes/docs.tsx", { id: "routes/docs-index" }),
    route("*", "routes/docs.tsx"),
  ]),
] satisfies RouteConfig;
