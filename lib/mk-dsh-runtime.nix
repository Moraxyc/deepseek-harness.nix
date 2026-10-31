{
  package,
  bundles,
  profileSeeder ? null,
  defaultProfile ? null,
  bundleCheckProfiles ? null,
}:
package.override {
  defaultBundles = bundles;
  profiles = { };
  agentPresets = { };
  defaultProfile = null;
  desktopProfile = null;
  homePatch = null;
  inherit profileSeeder;
  profileDefaultProfile = if profileSeeder == null then null else defaultProfile;
  profileBundleCheckProfiles = bundleCheckProfiles;
}
