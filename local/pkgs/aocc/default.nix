{ version ? "4.2.0", stdenv, fetchurl, lib }:
let versions =
{
  "4.1.0" = "1k9anln9hmdjflrkq4iacrmhma7gfrfj6d0b8ywxys0wfpdvy12v";
  "4.2.0" = "1aycw6ygzr1db6xf3z7v5lpznhs8j7gcpkawd304vcj5qw75cnpd";
};
in stdenv.mkDerivation
{
  pname = "aocc";
  inherit version;
  src = fetchurl
  {
    url = "https://download.amd.com/developer/eula/aocc/aocc-"
      + builtins.concatStringsSep "-" (lib.lists.take 2 (builtins.splitVersion version))
      + "/aocc-compiler-${version}.tar";
    sha256 = versions.${version};
  };
  dontBuild = true;
  installPhase =
  ''
    mkdir -p $out
    cp -r bin include lib lib32 libexec share $out
  '';
  dontFixup = true;
}
