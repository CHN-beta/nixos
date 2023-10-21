{
  lib, stdenv, mkPnpmPackage, fetchFromGitHub, fetchurl, nodejs_20, writeShellScript, buildFHSEnv,
  bash, cypress, vips, pkg-config
}:
let
  pname = "misskey";
  version = "2023.10.2";
  src = fetchFromGitHub
  {
    owner = "CHN-beta";
    repo = "misskey";
    rev = "3f813d9808ebc1774457e02add8fe9c7a6937ff7";
    sha256 = "63ZIil28jcMiL+c9FMj7m1OeCrLwsQZNHib+j8ar66s=";
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
  re2 = stdenv.mkDerivation rec
  {
    pname = "re2";
    version = "1.20.3";
    srcs =
    [
      (fetchurl
      {
        url = "https://github.com/uhop/node-re2/releases/download/1.20.3/linux-x64-115.br";
        sha256 = "0g2k0bki0zm0vaqpz25ww119qcs1flv63h6s5ib3103arpnzmb6d";
      })
      (fetchurl
      {
        url = "https://github.com/uhop/node-re2/releases/download/1.20.3/linux-x64-115.gz";
        sha256 = "1dr9zzzm67jknzvla1l5178lzmj6cfh8i1vsp5r4gkwdwbfh3ip0";
      })
      (fetchurl
      {
        url = "https://github.com/uhop/node-re2/releases/download/1.20.3/linux-x64-108.br";
        sha256 = "0wby987byhshb20np1gglj6y9ji7m7jza5jwa4hyxfxs1pkkmg1n";
      })
      (fetchurl
      {
        url = "https://github.com/uhop/node-re2/releases/download/1.20.3/linux-x64-108.gz";
        sha256 = "0q3dyxm63d2x0wxx23gdwym7r2gmaw4ahvmd35dgrj179ik290pi";
      })
      (fetchurl
      {
        url = "https://github.com/uhop/node-re2/releases/download/1.20.3/linux-x64-93.br";
        sha256 = "1wjmdni24353ppwfiyrv1zl9ci4g2habk0g2nz6b0sijagcy7bv3";
      })
      (fetchurl
      {
        url = "https://github.com/uhop/node-re2/releases/download/1.20.3/linux-x64-93.gz";
        sha256 = "0rgkryjh412g2m7rfrl2krsb9137prkk2y9ga8akn7qp1bqsbq1i";
      })
    ];
    phases = [ "installPhase" ];
    installPhase =
    ''
      mkdir -p $out/${version}
      for i in $srcs
      do
        cp $i $out/${version}/''${i#*-}
      done
    '';
  };
in
  stdenv.mkDerivation rec
  {
    inherit version src pname;
    buildInputs =
    [
      bash nodejs_20 nodejs_20.pkgs.typescript nodejs_20.pkgs.pnpm nodejs_20.pkgs.gulp cypress vips pkg-config
    ];
    nativeBuildInputs = buildInputs;
    CYPRESS_RUN_BINARY = "${cypress}/bin/Cypress";
    NODE_ENV = "production";
    RE2_DOWNLOAD_MIRROR = "${re2}";
    RE2_DOWNLOAD_SKIP_PATH = "true";
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
    passthru =
    {
      inherit originalPnpmPackage startScript re2;
    };
  }
