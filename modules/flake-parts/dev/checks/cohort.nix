{ ... }:

{
  perSystem =
    { pkgs, ... }:
    {
      checks.dsh-cohort = pkgs.dsh.dshCohort.check;
    };
}
