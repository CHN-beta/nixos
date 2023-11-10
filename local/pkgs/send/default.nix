{ buildNpmPackage, fetchFromGitHub, nodejs-16_x, nodePackages }:
buildNpmPackage.override { nodejs = nodejs-16_x; }
{
  pname = "send";
  version = "3.4.23";
  src = fetchFromGitHub
  {
    owner = "timvisee";
    repo = "send";
    rev = "6ad2885a168148fb996d3983457bc39527c7c8e5";
    sha256 = "AdwYNfTMfEItC4kBP+YozUQSBVnu/uzZvGta4wfwv0I=";
    leaveDotGit = true;
  };
  npmDepsHash = "sha256-r1iaurKuhpP0sevB5pFdtv9j1ikM1fKL7Jgakh4FzTI=";
  makeCacheWritable = true;
  PUPPETEER_SKIP_CHROMIUM_DOWNLOAD = "1";
  NODE_OPTIONS = "--openssl-legacy-provider";
  dontNpmInstall = true;
  NODE_ENV = "production";
  nativeBuildInputs = with nodePackages; [ rimraf webpack webpack-cli copy-webpack-plugin webpack-manifest-plugin ];
}
