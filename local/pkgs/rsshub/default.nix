{
  lib, stdenv, mkPnpmPackage, fetchFromGitHub, nodejs, writeShellScript,
  chromium, bash
}:
let
  name = "rsshub";
  src = fetchFromGitHub
  {
    owner = "DIYgod";
    repo = "RSSHub";
    rev = "4356fad91a268c81b8dacd2e3d9d07dbdce231a0";
    sha256 = "rUfXHtePIkBGF1U/tqrXHEsYC5jah2A7hoJZfEAnCoQ=";
  };
  originalPnpmPackage = mkPnpmPackage { inherit name src nodejs; };
  nodeModules = originalPnpmPackage.nodeModules.overrideAttrs { PUPPETEER_SKIP_DOWNLOAD = true; };
  rsshub-unwrapped = stdenv.mkDerivation
  {
    inherit src;
    name = "${name}-unwrapped";
    configurePhase = 
    ''
      export HOME=$NIX_BUILD_TOP # Some packages need a writable HOME
      export npm_config_nodedir=${nodejs}

      runHook preConfigure

      ln -s ${nodeModules}/. node_modules

      runHook postConfigure
    '';
    installPhase =
    ''
      runHook preInstall
      mkdir -p $out
      mv * .* $out
      runHook postInstall
    '';
  };
  startScript = writeShellScript "rsshub"
  ''
    cd ${rsshub-unwrapped}
    export PATH=${lib.makeBinPath [ bash nodejs nodejs.pkgs.pnpm chromium ]}:$PATH
    export CHROMIUM_EXECUTABLE_PATH=chromium
    pnpm start
  '';
in stdenv.mkDerivation
{
  inherit name;
  phases = [ "installPhase" ];
  installPhase =
  ''
    runHook preInstall
    mkdir -p $out/bin
    cp ${startScript} $out/bin/rsshub
    runHook postInstall
  '';
}
