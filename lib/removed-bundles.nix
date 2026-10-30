let
  migrationGuide = "https://moraxyc.github.io/deepseek-harness.nix/migration/#removed-bundles";
in
{
  auto-mode = "dsh: bundles.auto-mode was removed because upstream ended maintenance and archived the repository. Remove it from your bundle list and explicitly select a built-in permission mode; Auto review is not policy-equivalent to Sandbox Auto. See ${migrationGuide}";
  billion-context = "dsh: bundles.billion-context was removed because upstream stopped maintenance. Remove it from your bundle list. Upstream recommends https://github.com/ranxianglei/billion-context, which is not packaged here. See ${migrationGuide}";
  experimental-schedule-bundle = "dsh: bundles.experimental-schedule-bundle was removed in 0.2.1-alpha.1. Remove it from your bundle list; bundles.web-app now includes Schedule. See ${migrationGuide}";
  navbar = "dsh: bundles.navbar was removed because upstream archived the repository. Remove it from your bundle list; bundles.web-app includes built-in turn navigation. See ${migrationGuide}";
  oh-dsh = "dsh: bundles.oh-dsh is no longer maintained in this repository. Remove it from your bundle list. Use presets.web for the repository-maintained Web interface, or obtain Oh-DSH from https://github.com/hust-open-atom-club/oh-dsh. See ${migrationGuide}";
}
