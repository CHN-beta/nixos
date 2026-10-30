{
  lib,
  stdenvNoCC,
  fetchurl,
  makeWrapper,
  nodejs,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "hindsight-control-plane";
  version = "1.1.0";

  src = fetchurl {
    url = "https://registry.npmjs.org/@vectorize-io/hindsight-control-plane/-/hindsight-control-plane-${finalAttrs.version}.tgz";
    hash = "sha256-jvFwxSTnzvYhCuFeoP79CcvU9+yJWaFtGzDu8QllKnA=";
  };

  nativeBuildInputs = [ makeWrapper ];

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/hindsight-control-plane
    cp -r ./. $out/lib/hindsight-control-plane/

    makeWrapper ${nodejs}/bin/node $out/bin/hindsight-control-plane \
      --add-flags $out/lib/hindsight-control-plane/bin/cli.js \
      --prefix PATH : ${lib.makeBinPath [ nodejs ]} \
      --set-default NODE_ENV production

    runHook postInstall
  '';

  meta = {
    description = "Web UI for Hindsight";
    homepage = "https://github.com/vectorize-io/hindsight";
    license = lib.licenses.mit;
    mainProgram = "hindsight-control-plane";
    platforms = [ "x86_64-linux" ];
  };
})
