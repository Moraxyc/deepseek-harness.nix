{
  bashInteractive,
  dsh-workspace,
}:

dsh-workspace.kernel.overrideAttrs (oldAttrs: {
  passthru.runtimeDeps = (oldAttrs.passthru.runtimeDeps or [ ]) ++ [ bashInteractive ];
})
