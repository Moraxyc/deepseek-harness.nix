{
  lib,
}:

let
  # Emits a shell snippet that copies the tree `src` into the writable
  # directory `dest`.
  #
  # Composed dsh trees carry symlinks: pnpm and yarn layouts link into `.pnpm` or
  # into the source workspace, and the kernel links its `node_modules` into every
  # bundle as a resolution view. A destination that has to keep working without
  # the store it came from needs real files; a destination that stays in the same
  # closure can keep the links.
  #
  #   keepLinks    cp -r                 symlinks stay
  #   followLinks  cp -rL                symlinks are followed, so `dest` holds real files
  #   preserve     cp -a                 symlinks and file attributes stay
  #   fillMissing  cp -rL --update=none  only names `dest` lacks are added
  #
  # `src` and `dest` are shell fragments, not literals: a store path expands to
  # itself, `$out/lib` is expanded by the calling phase. `dest` is made writable
  # so later phases can prune or replace entries. `label` adds a missing-source
  # check; without it `cp` reports the failure.
  copy =
    flags:
    {
      src,
      dest,
      label ? null,
    }:
    (lib.optionalString (label != null) ''
      [ -d "${src}" ] || {
        printf '%s: source tree is missing: %s\n' ${lib.escapeShellArg label} "${src}" >&2
        exit 1
      }
    '')
    + ''
      mkdir -p "${dest}"
      cp ${flags} "${src}"/. "${dest}"/
      chmod -R u+w "${dest}"
    '';
in
{
  keepLinks = copy "-r";
  followLinks = copy "-rL";
  preserve = copy "-a";
  fillMissing = copy "-rL --update=none";
}
