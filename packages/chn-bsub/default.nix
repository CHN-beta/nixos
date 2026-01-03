{ stdenv, cmake, pkg-config, ftxui, biu, bsubConfig ? null, lib, bash }: stdenv.mkDerivation
{
  name = "chn-bsub";
  src = ./.;
  buildInputs = [ ftxui biu ];
  nativeBuildInputs = [ cmake pkg-config ];
  postInstall = "ln -s chn-bsub $out/bin/chn_bsub";
  cmakeFlags = [ "-DBSUB_SH=${bash}/bin/sh" ] ++ lib.optionals (bsubConfig != null) [ "-DBSUB_CONFIG=${bsubConfig}" ];
  passthru = { inherit bsubConfig; };
}
