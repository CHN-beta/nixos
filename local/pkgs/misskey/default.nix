{
  lib, stdenv, mkPnpmPackage, fetchFromGitHub, fetchurl, nodejs, writeShellScript, buildFHSEnv,
  bash, cypress, vips, pkg-config
}:
let
  pname = "misskey";
  version = "2023.12.0";
  src = fetchFromGitHub
  {
    owner = "CHN-beta";
    repo = "misskey";
    rev = "bec1dc37598b71c377643ee77330d4d6f7eb31f2";
    sha256 = "sha256-svLpG4xQ2mtsJ6gm+Ap8fZKTOl5V68XybGDvymsV4F4=";
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
      bash nodejs nodejs.pkgs.typescript nodejs.pkgs.pnpm nodejs.pkgs.gulp cypress vips pkg-config
    ];
    nativeBuildInputs = buildInputs;
    CYPRESS_RUN_BINARY = "${cypress}/bin/Cypress";
    NODE_ENV = "production";
    RE2_DOWNLOAD_MIRROR = "${re2}";
    RE2_DOWNLOAD_SKIP_PATH = "true";
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
      inherit originalPnpmPackage startScript re2;
    };
  }
