{
  package,
  profiles,
  agentPresets,
  defaultProfile,
  patch,
  ...
}@config:
package.override (
  (builtins.removeAttrs config [
    "package"
    "patch"
  ])
  // {
    homePatch = patch;
  }
)
