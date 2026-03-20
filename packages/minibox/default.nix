{ mkPnpmPackage, writeShellScript, nodejs, pnpm }: mkPnpmPackage
{
  src = ./.;
  extraAttrs =
  {
    NODE_ENV = "production";
    postInstall =
      let startScript = writeShellScript "minibox"
      ''
        export NODE_ENV=production
        export PATH="$PATH:${nodejs}/bin:${pnpm}/bin"
        pnpm start
      '';
      in
      ''
        mkdir -p $out/bin
        cp ${startScript} $out/bin/minibox
        mkdir -p $out/files
      '';
  };
}
