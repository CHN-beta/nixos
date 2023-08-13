{ buildNpmPackage, fetchFromGitHub, nodejs-16_x }:
buildNpmPackage.override { nodejs = nodejs-16_x; }
{
  pname = "send";
  version = "3.4.23";
  src = fetchFromGitHub
  {
    owner = "timvisee";
    repo = "send";
    rev = "6ad2885a168148fb996d3983457bc39527c7c8e5";
    hash = "sha256-/w9KhktDVSAmp6EVIRHFM63mppsIzYSm5F7CQQd/2+E=";
  };
  npmDepsHash = "sha256-r1iaurKuhpP0sevB5pFdtv9j1ikM1fKL7Jgakh4FzTI=";
  makeCacheWritable = true;
}
