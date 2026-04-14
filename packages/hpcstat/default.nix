{
  stdenv, cmake, pkg-config, dataDir ? "/var/lib/hpcstat", makeWrapper, lib,
  sqlite-orm, nlohmann_json, range-v3, openssh, sqlite, date, httplib, openssl, openxlsx, termcolor, duc, biu
}: stdenv.mkDerivation
{
  name = "hpcstat";
  src = ./.;
  buildInputs =
    [ sqlite-orm nlohmann_json range-v3 sqlite date httplib termcolor openssl biu openxlsx ];
  nativeBuildInputs = [ cmake pkg-config makeWrapper ];
  postInstall =
  ''
    wrapProgram $out/bin/hpcstat --set HPCSTAT_SHAREDIR $out/share/hpcstat \
      --set HPCSTAT_DATADIR ${dataDir} --set HPCSTAT_SSH_BINDIR ${openssh}/bin \
      --set HPCSTAT_DUC_BINDIR ${duc}/bin
  '';
  doCheck = true;
}
