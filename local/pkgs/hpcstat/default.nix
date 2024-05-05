{
  stdenv, cmake, pkg-config, standalone ? false, makeWrapper, version ? null, lib,
  boost, fmt, sqlite-orm, nlohmann_json, zpp-bits, range-v3, nameof, openssh, sqlite
}: stdenv.mkDerivation
{
  name = "hpcstat";
  src = ./.;
  buildInputs = [ boost fmt sqlite-orm nlohmann_json zpp-bits range-v3 nameof sqlite ];
  nativeBuildInputs = [ cmake pkg-config makeWrapper ];
  cmakeFlags = lib.optionals (version != null) [ ''-DHPCSTAT_VERSION="${version}"'' ];
  postInstall =
    if standalone then "cp ${openssh}/bin/{ssh-add,ssh-keygen} $out/bin"
    else
    ''
      wrapProgram $out/bin/hpcstat --set HPCSTAT_SHAREDIR $out/share/hpcstat \
        --set HPCSTAT_DATADIR /var/lib/hpcstat --set HPCSTAT_SSH_BINDIR ${openssh}/bin
    '';
}
