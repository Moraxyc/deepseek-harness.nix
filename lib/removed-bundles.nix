let
  migrationGuide = "https://moraxyc.github.io/deepseek-harness.nix/migration/#removed-bundles";
in
{
  experimental-schedule-bundle = "dsh: bundles.experimental-schedule-bundle was removed in 0.2.1-alpha.1. Remove it from your bundle list; bundles.web-app now includes Schedule. See ${migrationGuide}";
  oh-dsh = "dsh: bundles.oh-dsh is no longer maintained in this repository. Remove it from your bundle list. Use presets.web for the repository-maintained Web interface, or obtain Oh-DSH from https://github.com/hust-open-atom-club/oh-dsh. See ${migrationGuide}";
}
