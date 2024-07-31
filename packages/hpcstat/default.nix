{
  stdenv, cmake, pkg-config, standalone ? false, version ? null, makeWrapper, lib,
  sqlite-orm, nlohmann_json, range-v3, openssh, sqlite, date, httplib, openssl, openxlsx, termcolor, duc, biu
}: stdenv.mkDerivation
{
  name = "hpcstat";
  src = ./.;
  buildInputs =
    [ sqlite-orm nlohmann_json range-v3 sqlite date httplib termcolor openssl biu openxlsx ];
  nativeBuildInputs = [ cmake pkg-config makeWrapper ];
  cmakeFlags = lib.optionals (version != null) [ "-DHPCSTAT_VERSION=${version}" ];
  postInstall =
    if standalone then "cp ${openssh}/bin/{ssh-add,ssh-keygen} ${duc}/bin/duc $out/bin"
    else
    ''
      wrapProgram $out/bin/hpcstat --set HPCSTAT_SHAREDIR $out/share/hpcstat \
        --set HPCSTAT_DATADIR /var/lib/hpcstat --set HPCSTAT_SSH_BINDIR ${openssh}/bin \
        --set HPCSTAT_DUC_BINDIR ${duc}/bin
    '';
}
