{
  lib, mkPnpmPackage, nodejs, writeShellScript,
  bash, cypress, vips, src
}: (mkPnpmPackage.override { inherit nodejs; })
  {
    inherit src;
    extraIntegritySha256."https://github.com/aiscript-dev/aiscript-languageserver/releases/download/0.1.6/aiscript-dev-aiscript-languageserver-0.1.6.tgz" = "0092d5r67bhf4xkvrdn4a2rm1drjzy7b5sw8mi7hp4pqvpc20ylr";
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
