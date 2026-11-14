let
  migrationGuide = "https://moraxyc.github.io/deepseek-harness.nix/migration/#removed-bundles";
in
{
  auto-mode = "dsh: bundles.auto-mode was removed because upstream ended maintenance and archived the repository. Remove it from your bundle list and explicitly select a built-in permission mode; Auto review is not policy-equivalent to Sandbox Auto. See ${migrationGuide}";
  at-file = "dsh: bundles.at-file is no longer maintained in this repository. Remove it from your bundle list. See ${migrationGuide}";
  billion-context = "dsh: bundles.billion-context was removed because upstream stopped maintenance. Remove it from your bundle list. Upstream recommends https://github.com/ranxianglei/billion-context, which is not packaged here. See ${migrationGuide}";
  experimental-agent-team-profile = "dsh: bundles.experimental-agent-team-profile was removed in 0.2.2-rc.2. Remove it from your bundle list and enable Team per session in the built-in interface. See ${migrationGuide}";
  experimental-schedule-bundle = "dsh: bundles.experimental-schedule-bundle was removed in 0.2.1-alpha.1. Remove it from your bundle list; bundles.web-app now includes Schedule. See ${migrationGuide}";
  graph-memory = "dsh: bundles.graph-memory is no longer maintained in this repository. Remove it from your bundle list; keep bundles.mneme or bundles.mnemon for cross-session memory. See ${migrationGuide}";
  liang-saint-slider = "dsh: bundles.liang-saint-slider is no longer maintained in this repository. Remove it from your bundle list. See ${migrationGuide}";
  liang-skin = "dsh: bundles.liang-skin is no longer maintained in this repository. Remove it from your bundle list. See ${migrationGuide}";
  memory-evolve = "dsh: bundles.memory-evolve is no longer maintained in this repository. Remove it from your bundle list; keep bundles.mneme or bundles.mnemon for long-term memory. See ${migrationGuide}";
  memento = "dsh: bundles.memento is no longer maintained in this repository. Remove it from your bundle list; keep bundles.mneme or bundles.mnemon for cross-session memory. See ${migrationGuide}";
  message-edit = "dsh: bundles.message-edit is no longer maintained in this repository. Remove it from your bundle list. See ${migrationGuide}";
  modlens = "dsh: bundles.modlens is no longer maintained in this repository. Remove it from your bundle list. See ${migrationGuide}";
  modsearch = "dsh: bundles.modsearch is no longer maintained in this repository. Remove it from your bundle list. See ${migrationGuide}";
  navbar = "dsh: bundles.navbar was removed because upstream archived the repository. Remove it from your bundle list; bundles.web-app includes built-in turn navigation. See ${migrationGuide}";
  noema = "dsh: bundles.noema is no longer maintained in this repository. Remove it from your bundle list; keep bundles.mneme or bundles.mnemon for cross-session memory. See ${migrationGuide}";
  notification = "dsh: bundles.notification is no longer maintained in this repository. Remove it from your bundle list. See ${migrationGuide}";
  oh-dsh = "dsh: bundles.oh-dsh is no longer maintained in this repository. Remove it from your bundle list. Use presets.web for the repository-maintained Web interface, or obtain Oh-DSH from https://github.com/hust-open-atom-club/oh-dsh. See ${migrationGuide}";
  opentelemetry = "dsh: bundles.opentelemetry is no longer maintained in this repository. Remove it from your bundle list. See ${migrationGuide}";
  plugin-check = "dsh: bundles.plugin-check is no longer maintained in this repository. Remove it from your bundle list. See ${migrationGuide}";
  security-audit = "dsh: bundles.security-audit is no longer maintained in this repository. Remove it from your bundle list. See ${migrationGuide}";
  session-health = "dsh: bundles.session-health is no longer maintained in this repository. Remove it from your bundle list. See ${migrationGuide}";
}
