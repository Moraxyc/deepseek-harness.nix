{ ... }:

{
  perSystem =
    { pkgs, ... }:
    {
      # Bundle builds read cohort tarballs, so a missing or renamed member would
      # surface as a `tar` failure inside an unrelated package. Report it here.
      checks.dsh-cohort = pkgs.dsh.dshCohort.check;
    };
}
