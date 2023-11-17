{
  lib, stdenv, mkPnpmPackage, fetchFromGitHub, fetchurl, nodejs_20, writeShellScript, buildFHSEnv,
  bash, cypress, vips, pkg-config
}:
let
  pname = "misskey";
  version = "2023.11.1";
  src = fetchFromGitHub
  {
    owner = "CHN-beta";
    repo = "misskey";
    rev = "1e5134816cc23600a0448a62b34aadfe573c3bbc";
    sha256 = "ihkFVTpwEELmxAw4Lw01pWr8j6u2oLpfcw3laVUFCO4=";
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
    version = "1.20.8";
    srcs =
    [
      (fetchurl
      {
        url = "https://github.com/uhop/node-re2/releases/download/1.20.8/linux-x64-120.br";
        sha256 = "0f2l658xxc2112mbqpkyfic3vhjgdyafbfi14b6n40skyd6lijcq";
      })
      (fetchurl
      {
        url = "https://github.com/uhop/node-re2/releases/download/1.20.8/linux-x64-120.gz";
        sha256 = "1v5n8i16188xpwx1jr8gcc1a99v83hlbh5hldl4i376vh0lwsxlq";
      })
      (fetchurl
      {
        url = "https://github.com/uhop/node-re2/releases/download/1.20.8/linux-x64-115.br";
        sha256 = "0cyqmgqk5cwik27wh4ynaf94v4w6p1fsavm07xh8xfmdim2sr9kd";
      })
      (fetchurl
      {
        url = "https://github.com/uhop/node-re2/releases/download/1.20.8/linux-x64-115.gz";
        sha256 = "0i3iykw13d5qfd5s6pq6kx6cbd64vfb3w65f9bnj87qz44la84ic";
      })
      (fetchurl
      {
        url = "https://github.com/uhop/node-re2/releases/download/1.20.8/linux-x64-108.br";
        sha256 = "1467frfapqhi839r2v0p0wh76si3lihwzwgl9098mj7mwhjfl4lx";
      })
      (fetchurl
      {
        url = "https://github.com/uhop/node-re2/releases/download/1.20.8/linux-x64-108.gz";
        sha256 = "0hykpqdrn55x83v1kzz6bdvrp24hgz3rwmwbdfl2saz576krzg1c";
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
