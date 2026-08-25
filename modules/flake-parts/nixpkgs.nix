{
  inputs,
  self,
  ...
}:
{
  perSystem =
    { system, ... }:
    {
      _module.args.pkgs = import inputs.nixpkgs {
        inherit system;
        config.allowUnfreePredicate =
          package: inputs.nixpkgs.lib.getName package == "dsh-subagent-claude-code";
        overlays = [ self.overlays.default ];
      };
    };
}
