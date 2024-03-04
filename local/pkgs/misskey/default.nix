{
  lib, stdenv, mkPnpmPackage, fetchurl, nodejs, writeShellScript, buildFHSEnv,
  bash, cypress, vips, pkg-config, src
}:
let
  name = "misskey";
  originalPnpmPackage = mkPnpmPackage
  {
    inherit name src nodejs;
    copyPnpmStore = true;
    extraIntegritySha256."https://github.com/aiscript-dev/aiscript-languageserver/releases/download/0.1.5/aiscript-dev-aiscript-languageserver-0.1.5.tgz" = "1mhnwa8h48bc21f0zv8q93aphiqz9i70r7m4xsa4sd1mlncfgyl7";
  };
  startScript = writeShellScript "misskey"
  ''
    export PATH=${lib.makeBinPath [ bash nodejs nodejs.pkgs.pnpm nodejs.pkgs.gulp cypress ]}:$PATH
    export CYPRESS_RUN_BINARY="${cypress}/bin/Cypress"
    export NODE_ENV=production
    pnpm run migrateandstart
  '';
  tensorflow = fetchurl
  {
    url = "https://storage.googleapis.com/tensorflow/libtensorflow/libtensorflow-cpu-linux-x86_64-2.9.1.tar.gz";
    sha256 = "0wq1ha1cylfabg4x6al989w5hg80i4v4c6fin485xnz38qjhslbz";
  };
in
  stdenv.mkDerivation rec
  {
    inherit src name;
    buildInputs =
    [
      bash nodejs nodejs.pkgs.typescript nodejs.pkgs.pnpm nodejs.pkgs.gulp cypress vips pkg-config
    ];
    nativeBuildInputs = buildInputs;
    CYPRESS_RUN_BINARY = "${cypress}/bin/Cypress";
    NODE_ENV = "production";
    TFJS_NODE_BASE_URI = "file:/${builtins.head (builtins.split "-" "${tensorflow}")}-libtensorflow-";
    configurePhase =
    ''
      export HOME=$NIX_BUILD_TOP # Some packages need a writable HOME
      export npm_config_nodedir=${nodejs}
      pnpm config set reporter append-only

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
