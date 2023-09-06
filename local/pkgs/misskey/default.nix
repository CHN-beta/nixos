{
  lib, stdenv, mkPnpmPackage, fetchFromGitHub, nodejs_20, writeShellScript, buildFHSEnv,
  bash, cypress, vips, pkg-config
}:
let
  pname = "misskey";
  version = "13.14.2";
  src = fetchFromGitHub
  {
    owner = "CHN-beta";
    repo = "misskey";
    rev = "a05feaf47f1c5da43e7129bec8ceccf7939eb4a6";
    hash = "sha256-hjNT7dcOkN+OiKNn76l/aJ4u6BqvnrQitUj0iZWJj0o=";
    fetchSubmodules = true;
  };
  originalPnpmPackage = mkPnpmPackage
  {
    inherit pname version src;
    nodejs = nodejs_20;
    copyPnpmStore = true;
  };
  startScript = writeShellScript "misskey"
  ''
    export PATH=${lib.makeBinPath [ bash nodejs_20 nodejs_20.pkgs.pnpm nodejs_20.pkgs.gulp cypress ]}:$PATH
    export CYPRESS_RUN_BINARY="${cypress}/bin/Cypress"
    export NODE_ENV=production
    pnpm run migrateandstart
  '';
in
  stdenv.mkDerivation
  {
    inherit version src pname;
    nativeBuildInputs =
      [ bash nodejs_20 nodejs_20.pkgs.typescript nodejs_20.pkgs.pnpm nodejs_20.pkgs.gulp cypress vips pkg-config ];
    CYPRESS_RUN_BINARY = "${cypress}/bin/Cypress";
    NODE_ENV = "production";
    configurePhase =
    ''
      export HOME=$NIX_BUILD_TOP # Some packages need a writable HOME
      export npm_config_nodedir=${nodejs_20}

      runHook preConfigure

      store=$(pnpm store path)
      mkdir -p $(dirname $store)

      cp -f ${originalPnpmPackage.passthru.patchedLockfileYaml} pnpm-lock.yaml
      cp -RL ${originalPnpmPackage.passthru.pnpmStore} $store
      chmod -R +w $store
      pnpm install --frozen-lockfile --offline

      runHook postConfigure
    '';
    buildPhase =
    ''
      runHook preBuild
      pnpm run build
      runHook postBuild
    '';
    installPhase =
    ''
      runHook preInstall
      mkdir -p $out
      mv * .* $out
      mkdir -p $out/bin
      cp ${startScript} $out/bin/misskey
      mkdir -p $out/files
      runHook postInstall
    '';
  }
