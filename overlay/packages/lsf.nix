{ stdenv, src, autoPatchelfHook, libz }: stdenv.mkDerivation rec
{
  name = "lsf";
  inherit src;
  dontConfigure = true;
  dontBuild = true;
  buildInputs = [ stdenv.cc.cc libz ];
  nativeBuildInputs = [ autoPatchelfHook ];
  autoPatchelfIgnoreMissingDeps = [ "libnvidia-ml.so.1" ];
  installPhase =
  ''
    runHook preInstall
    mkdir -p $out
    cp -r * $out
    rm $out/lib/{hwloc_nvml,sec_ego_kerberos,sec_ego_gsskrb,sec_ego_pam_default}.so
    runHook postInstall
  '';
}
