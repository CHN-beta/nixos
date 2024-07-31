{
  lib, mkPnpmPackage, nodejs, writeShellScript, src,
  bash, cypress, vips, python3
}: (mkPnpmPackage.override { inherit nodejs; })
  {
    inherit src;
    extraIntegritySha256."https://github.com/aiscript-dev/aiscript-languageserver/releases/download/0.1.6/aiscript-dev-aiscript-languageserver-0.1.6.tgz" = "0092d5r67bhf4xkvrdn4a2rm1drjzy7b5sw8mi7hp4pqvpc20ylr";
    extraNativeBuildInputs = [ bash nodejs.pkgs.typescript nodejs.pkgs.gulp python3 ];
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
          export COREPACK_ENABLE_STRICT=0
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
