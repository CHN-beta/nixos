{
  lib, stdenv, mkPnpmPackage, fetchFromGitHub, fetchurl, nodejs_20, writeShellScript, buildFHSEnv,
  bash, cypress, vips, pkg-config
}:
let
  pname = "misskey";
  version = "2023.11.0";
  src = fetchFromGitHub
  {
    owner = "CHN-beta";
    repo = "misskey";
    rev = "aa182cd92ea5dc446f4d1ae2bf942bf46c645811";
    sha256 = "hotUhy4Rhm4QWO7oYH3UENr7LewF+/dC8rsaKD0y2uc=";
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
    version = "1.20.5";
    srcs =
    [
      (fetchurl
      {
        url = "https://github.com/uhop/node-re2/releases/download/1.20.5/linux-x64-120.br";
        sha256 = "07hwfgb7yw7pad2svkmx8qapc490xxxk0bbbx51h3kajckw98b9w";
      })
      (fetchurl
      {
        url = "https://github.com/uhop/node-re2/releases/download/1.20.5/linux-x64-120.gz";
        sha256 = "0c3z7bw4b1hgafv4n86pkg3z627zsmlzaghbzpyb81pilf1hzn8z";
      })
      (fetchurl
      {
        url = "https://github.com/uhop/node-re2/releases/download/1.20.5/linux-x64-115.br";
        sha256 = "17sbfx0dbfqc42qsxbqnn94a3vsih4mc06d8svbarvx5b5x0mg31";
      })
      (fetchurl
      {
        url = "https://github.com/uhop/node-re2/releases/download/1.20.5/linux-x64-115.gz";
        sha256 = "1lnmad2vqhjck0fjs55z74jm9psl1p81g84k2nn9gxbqnk2lxsjd";
      })
      (fetchurl
      {
        url = "https://github.com/uhop/node-re2/releases/download/1.20.5/linux-x64-108.br";
        sha256 = "1c605zipadwbd8z3mzvjzw4x9v89jdq19m4hmd6bqbrcz3qbgg4n";
      })
      (fetchurl
      {
        url = "https://github.com/uhop/node-re2/releases/download/1.20.5/linux-x64-108.gz";
        sha256 = "0sqsn3rdlg8abqcn7i9gyhpsd1znfj1x2bxm1nj222g0svp1mry3";
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
