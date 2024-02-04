{
  lib, mkPnpmPackage, nodejs, writeShellScriptBin,
  bash, cypress, vips, pkg-config, src
}:
let
  unwrapped = mkPnpmPackage
  {
    inherit src nodejs;
    name = "misskey-unwrapped";
    installEnv = { CYPRESS_RUN_BINARY = "${cypress}/bin/Cypress"; NODE_ENV = "production"; };
    copyPnpmStore = true;
    distDir = ".";
    noDevDependencies = true;
  };
in writeShellScriptBin "misskey"
''
  cd ${unwrapped}
  export PATH=${lib.makeBinPath [ bash nodejs nodejs.pkgs.pnpm nodejs.pkgs.gulp cypress ]}:$PATH
  export CYPRESS_RUN_BINARY="${cypress}/bin/Cypress"
  export NODE_ENV=production
  pnpm run migrateandstart
''
