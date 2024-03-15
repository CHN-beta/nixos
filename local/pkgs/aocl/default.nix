{ version ? "4.2.0", stdenv, fetchurl, lib }:
let versions =
{
  "4.1.0" = "04780c2zks0g76c4n4a2cbbhs1qz4lza4ffiw1fj0md3f1lxihr5";
  "4.2.0" = "0p4x0zza6y18hjjs1971gyc5kjd2f8nzzynp2jabhl2vxiys2nnj";
};
in stdenv.mkDerivation
{
  pname = "aocl";
  inherit version;
  src = fetchurl
  {
    url = "https://download.amd.com/developer/eula/aocl/aocl-"
      + builtins.concatStringsSep "-" (lib.lists.take 2 (builtins.splitVersion version))
      + "/aocl-linux-aocc-${version}.tar.gz";
    sha256 = versions.${version};
  };
  dontBuild = true;
  installPhase =
  ''
    installDir=$(mktemp -d)
    bash ./install.sh -t $installDir
    mkdir -p $out
    cp -r $installDir/${version}/aocc/lib_LP64 $out/lib
    cp -r $installDir/${version}/aocc/include_LP64 $out/include
  '';
  dontFixup = true;
}
