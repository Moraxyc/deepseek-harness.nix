{ makeSetupHook }:
makeSetupHook {
  name = "dsh-workspace-patch-hook";
  meta.description = "Patch a DeepSeek Harness workspace for Nix packaging";
} ./hook.sh
