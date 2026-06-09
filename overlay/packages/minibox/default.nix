{
  stdenvNoCC,
  fetchPnpmDeps,
  lib,
  pnpmConfigHook,
  nodejs,
  pnpm,
}:
stdenvNoCC.mkDerivation rec {
  pname = "minibox";
  version = "0.1.0";
  src = ./.;
  nativeBuildInputs = [
    pnpmConfigHook
    nodejs
    pnpm
  ];
  pnpmDeps = fetchPnpmDeps {
    inherit pname version src;
    fetcherVersion = 3;
    hash = "sha256-tsoIsKc6LaGMdHzAYQDELqa0g4ZpFiKzDQYIkxM62lY=";
  };
  buildPhase = ''
    runHook preBuild
    pnpm build
    runHook postBuild
  '';
  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp -r .next/standalone/{*,.*} $out
    cp -r public $out
    cp -r .next/static $out/.next/static
    rm $out/node_modules/.pnpm/node_modules/semver
    runHook postInstall
  '';
}
