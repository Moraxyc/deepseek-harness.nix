{
  package,
  bundles,
  profileSeeder ? null,
  defaultProfile ? null,
  # bundleCheckProfiles from the mkProfileArtifacts call that built profileSeeder.
  bundleCheckProfiles ? null,
}:
assert profileSeeder == null || bundleCheckProfiles != null;
package.override (
  {
    defaultBundles = bundles;
    profiles = { };
    agentPresets = { };
    defaultProfile = null;
    desktopProfile = null;
    homePatch = null;
    inherit profileSeeder;
    profileDefaultProfile = if profileSeeder == null then null else defaultProfile;
  }
  // (if profileSeeder == null then { } else { profileBundleCheckProfiles = bundleCheckProfiles; })
)
