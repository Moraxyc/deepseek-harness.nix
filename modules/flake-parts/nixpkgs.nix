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
        config.allowUnfreePredicate = package: (package.pname or null) == "claude-code";
        overlays = [ self.overlays.default ];
      };
    };
}
