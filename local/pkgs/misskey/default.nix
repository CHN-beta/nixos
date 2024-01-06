{
  lib, stdenv, mkPnpmPackage, fetchFromGitHub, fetchurl, nodejs, writeShellScript, buildFHSEnv,
  bash, cypress, vips, pkg-config
}:
let
  pname = "misskey";
  version = "2023.12.2";
  src = fetchFromGitHub
  {
    owner = "CHN-beta";
    repo = "misskey";
    rev = "cd1d0ab06eb6b7e06afdfae9a12b2d2829564229";
    hash = "sha256-sKEZ1ZpyA/02CNwiOMIOS5f/csx6ELDwCVJYc+oMChM=";
    fetchSubmodules = true;
  };
  originalPnpmPackage = mkPnpmPackage
  {
    inherit pname version src nodejs;
    copyPnpmStore = true;
  };
  startScript = writeShellScript "misskey"
  ''
    export PATH=${lib.makeBinPath [ bash nodejs nodejs.pkgs.pnpm nodejs.pkgs.gulp cypress ]}:$PATH
    export CYPRESS_RUN_BINARY="${cypress}/bin/Cypress"
    export NODE_ENV=production
    pnpm run migrateandstart
  '';
in
  stdenv.mkDerivation rec
  {
    inherit version src pname;
    buildInputs =
    [
      bash nodejs nodejs.pkgs.typescript nodejs.pkgs.pnpm nodejs.pkgs.gulp cypress vips pkg-config
    ];
    nativeBuildInputs = buildInputs;
    CYPRESS_RUN_BINARY = "${cypress}/bin/Cypress";
    NODE_ENV = "production";
    configurePhase =
    ''
      export HOME=$NIX_BUILD_TOP # Some packages need a writable HOME
      export npm_config_nodedir=${nodejs}

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
    passthru =
    {
      inherit originalPnpmPackage startScript;
    };
  }
