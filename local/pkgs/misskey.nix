{
  lib, mkPnpmPackage, nodejs, writeShellScript,
  bash, cypress, vips, src
}: (mkPnpmPackage.override { inherit nodejs; })
  {
    inherit src;
    extraIntegritySha256."https://github.com/aiscript-dev/aiscript-languageserver/releases/download/0.1.5/aiscript-dev-aiscript-languageserver-0.1.5.tgz" = "1mhnwa8h48bc21f0zv8q93aphiqz9i70r7m4xsa4sd1mlncfgyl7";
    extraNativeBuildInputs = [ bash nodejs.pkgs.typescript nodejs.pkgs.gulp ];
    extraAttrs =
    {
      CYPRESS_INSTALL_BINARY = "0";
      NODE_ENV = "production";
      postInstall =
        let startScript = writeShellScript "misskey"
        ''
          export PATH=${lib.makeBinPath [ bash nodejs nodejs.pkgs.pnpm nodejs.pkgs.gulp cypress ]}:$PATH
          export CYPRESS_RUN_BINARY="${cypress}/bin/Cypress"
          export NODE_ENV=production
          pnpm run migrateandstart
        '';
        in
        ''
          mkdir -p $out/bin
          cp ${startScript} $out/bin/misskey
          mkdir -p $out/files
        '';
    };
  }
