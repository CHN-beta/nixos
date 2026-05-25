# TODO: update to use pnpm.setupHook
{
  lib, mkPnpmPackage, nodejs, writeShellScript, src, extraIntegritySha256,
  bash, cypress, vips, python3, autoPatchelfHook, typescript, pnpm
}: (mkPnpmPackage.override { inherit nodejs; })
{
  inherit src extraIntegritySha256;
  extraNativeBuildInputs = [ bash typescript python3 autoPatchelfHook ];
  extraAttrs =
  {
    env = { CYPRESS_INSTALL_BINARY = "0"; NODE_ENV = "production"; };
    postInstall =
      let startScript = writeShellScript "misskey"
      ''
        export PATH=${lib.makeBinPath [ bash nodejs pnpm cypress ]}:$PATH
        export CYPRESS_RUN_BINARY="${cypress}/bin/Cypress"
        export NODE_ENV=production
        export COREPACK_ENABLE_STRICT=0
        pnpm run migrateandstart
      '';
      in
      ''
        mkdir -p $out/bin
        cp ${startScript} $out/bin/misskey
        mkdir -p $out/files
      '';
    preBuild =
    ''
      autoPatchelf node_modules/.pnpm/sass-embedded-linux-x64*/node_modules/sass-embedded-linux-x64/dart-sass/src/dart
    '';
    autoPatchelfIgnoreMissingDeps = [ "libc.musl-x86_64.so.1" ];
  };
}
