{
  lib,
}:

let
  # `src` and `dest` are shell fragments expanded by the calling phase.
  # Use followLinks when the destination must work without the source closure.
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
