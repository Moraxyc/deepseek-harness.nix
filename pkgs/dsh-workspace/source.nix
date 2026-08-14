{ fetchFromGitHub }:

let
  source = {
    version = "0.1.0-rc.5";
    rev = "47f943859bef60e4160492346772ded9b24f765a";
    sourceHash = "sha256-ZPGCNoPXVjP76Tm/tFPDX2X95cd83M4iHLmVP5dR+Ps=";
    pnpmDepsHash = "sha256-+dkclQcDhAmHmB6dM8bffc3pMrivJR1T1wi/56IgQro=";
  };
in
source
// {
  src = fetchFromGitHub {
    owner = "deepseek-ai";
    repo = "deepseek-harness";
    inherit (source) rev;
    hash = source.sourceHash;
  };
}
