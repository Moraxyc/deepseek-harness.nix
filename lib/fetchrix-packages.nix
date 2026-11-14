{ lib, dsh }:
let
  packages = (lib.importTOML ../fetchrix.toml).packages;
in
lib.mapAttrs (
  name: spec: source:
  let
    package =
      if lib.hasPrefix "bundles." name then
        dsh.bundles.${lib.removePrefix "bundles." name}
      else
        dsh.${name};
  in
  package.override {
    dshSources = dsh.dshSources // {
      ${name} =
        (dsh.dshSources.${name} or { }) // lib.mapAttrs (_: _: lib.fakeHash) spec.derive // source;
    };
  }
) (lib.filterAttrs (_: spec: spec ? derive) packages)
