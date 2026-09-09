{
  bashInteractive,
  dsh-workspace,
}:

dsh-workspace.kernel.overrideAttrs (oldAttrs: {
  pname = "dsh-kernel";
  passthru.runtimeDeps = (oldAttrs.passthru.runtimeDeps or [ ]) ++ [ bashInteractive ];
})
