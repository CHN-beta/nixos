{
  lib, mkPnpmPackage, nodejs, writeShellScript,
  bash, chromium, src, git
}: (mkPnpmPackage.override { inherit nodejs; })
  {
    inherit src;
    extraNativeBuildInputs = [ bash git ];
    extraAttrs =
    {
      PUPPETEER_SKIP_DOWNLOAD = true;
      postInstall =
        let startScript = writeShellScript "rsshub"
        ''
          export PATH=${lib.makeBinPath [ bash nodejs nodejs.pkgs.pnpm chromium git ]}:$PATH
          export CHROMIUM_EXECUTABLE_PATH=chromium
          pnpm start
        '';
        in
        ''
          mkdir -p $out/bin
          cp ${startScript} $out/bin/rsshub
        '';
    };
  }
