# TODO: update to use pnpm.setupHook
{
  lib,
  mkPnpmPackage,
  nodejs,
  writeShellScript,
  src,
  extraIntegritySha256,
  bash,
  cypress,
  vips,
  python3,
  autoPatchelfHook,
  typescript,
  pnpm,
  runCommand,
  re2,
}:
let
  re2Filename = lib.head (builtins.match ".*/[a-z0-9]{32}-(.+)" "${re2}");
  re2Dir = runCommand "re2" { } ''
    mkdir -p $out
    cp ${re2} $out/${re2Filename}
  '';
in
(mkPnpmPackage.override { inherit nodejs; }) {
  inherit src extraIntegritySha256;
  extraNativeBuildInputs = [
    bash
    typescript
    python3
    autoPatchelfHook
  ];
  extraAttrs = {
    env = {
      CYPRESS_INSTALL_BINARY = "0";
      NODE_ENV = "production";
      RE2_DOWNLOAD_MIRROR = "${re2Dir}";
      RE2_DOWNLOAD_SKIP_PATH = "1";
      RE2_DOWNLOAD_SKIP_VER = "1";
    };
    postInstall =
      let
        startScript = writeShellScript "misskey" ''
          export PATH=${
            lib.makeBinPath [
              bash
              nodejs
              pnpm
              cypress
            ]
          }:$PATH
          export CYPRESS_RUN_BINARY="${cypress}/bin/Cypress"
          export NODE_ENV=production
          export COREPACK_ENABLE_STRICT=0
          export PNPM_CONFIG_VERIFY_DEPS_BEFORE_RUN=false
          pnpm run migrateandstart
        '';
      in
      ''
        mkdir -p $out/bin
        cp ${startScript} $out/bin/misskey
        mkdir -p $out/files
      '';
    preBuild = ''
      autoPatchelf node_modules/.pnpm/sass-embedded-linux-x64*/node_modules/sass-embedded-linux-x64/dart-sass/src/dart
    '';
    autoPatchelfIgnoreMissingDeps = [ "libc.musl-x86_64.so.1" ];
  };
}
