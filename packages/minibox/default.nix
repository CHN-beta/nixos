{
  mkPnpmPackage, writeShellScript, bash, cypress, python3
}: mkPnpmPackage
{
  src = ./.;
  # extraNativeBuildInputs = [ bash nodejs.pkgs.typescript nodejs.pkgs.gulp python3 ];
  extraAttrs =
  {
    NODE_ENV = "production";
    postInstall =
      let startScript = writeShellScript "minibox"
      ''
        export NODE_ENV=production
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
