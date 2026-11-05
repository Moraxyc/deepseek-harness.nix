{
  package,
  bundles,
  profileSeeder ? null,
  defaultProfile ? null,
  bundleCheckProfiles ? null,
  runtimeRoot ? null,
}:
package.override {
  defaultBundles = bundles;
  profiles = { };
  agentPresets = { };
  defaultProfile = null;
  desktopProfile = null;
  homePatch = null;
  inherit profileSeeder runtimeRoot;
  profileDefaultProfile = if profileSeeder == null then null else defaultProfile;
  profileBundleCheckProfiles = bundleCheckProfiles;
}
