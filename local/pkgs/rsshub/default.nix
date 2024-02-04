{
  lib, mkPnpmPackage, nodejs, writeShellScriptBin, src,
  chromium, bash
}:
let
  unwrapped = mkPnpmPackage
  {
    name = "rsshub-unwrapped";
    inherit src nodejs;
    installEnv.PUPPETEER_SKIP_DOWNLOAD = "1";
    script = "build:all";
    distDir = ".";
  };
in writeShellScriptBin "rsshub"
''
  cd ${unwrapped}
  export PATH=${lib.makeBinPath [ bash nodejs nodejs.pkgs.pnpm chromium ]}:$PATH
  export CHROMIUM_EXECUTABLE_PATH=chromium
  pnpm start
''
