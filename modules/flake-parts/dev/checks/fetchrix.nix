{ ... }:
{
  perSystem =
    { lib, pkgs, ... }:
    let
      config = lib.importTOML ../../../../fetchrix.toml;
      locked = lib.importJSON ../../../../_sources/lock.json;
      names = lib.attrNames config.packages;
      packages = import ../../../../lib/fetchrix-packages.nix {
        inherit lib;
        dsh = pkgs.dsh;
      };
      source = pkgs.writeTextDir "package.json" (
        builtins.toJSON {
          name = "@changfenhuang/dsh-annotation";
          version = "1.0.0";
          scripts.build = "unused";
          devDependencies.unused = "1.0.0";
        }
      );
      package = packages."bundles.annotation" {
        src = source;
        version = "99.0.0";
        artifacts = { };
      };
      prepared = pkgs.applyPatches {
        src = package.src;
        inherit (package.npmDeps) postPatch nativeBuildInputs;
      };
      artifactsExist = lib.all (
        name:
        lib.all (path: builtins.pathExists (../../../../_sources + "/${path}")) (
          lib.attrValues (locked.packages.${name}.artifacts or { })
        )
      ) names;
    in
    {
      checks.fetchrix =
        assert names == lib.attrNames locked.packages;
        assert artifactsExist;
        assert package.version == "99.0.0";
        assert package.src == source;
        assert pkgs.dsh.bundles.annotation.version != package.version;
        assert !(config.packages."bundles.annotation" ? prepare);
        assert config.packages."bundles.annotation".derive.npmDepsHash.select == "npmDeps";
        assert config.packages."bundles.web-ui".prepare.artifacts."pnpm-lock.json".type == "json";
        pkgs.runCommand "fetchrix-integration" { nativeBuildInputs = [ pkgs.jq ]; } ''
          jq -e '.version == "99.0.0" and .packages[""].version == "99.0.0"' \
            ${prepared}/package-lock.json >/dev/null
          jq -e 'has("scripts") == false and has("devDependencies") == false' \
            ${prepared}/package.json >/dev/null
          touch "$out"
        '';
    };
}
