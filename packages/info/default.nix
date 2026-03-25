{ lib, stdenv, cmake, pkg-config, configFile ? null, buildMain ? true, slurm, biu }: stdenv.mkDerivation
{
  name = "info";
  src = ./.;
  buildInputs = [ slurm biu ];
  nativeBuildInputs = [ cmake pkg-config ];
  cmakeFlags = (lib.optionals (configFile != null) [ "-DINFO_CONFIG_FILE=${configFile}" ])
    ++ (lib.optionals (!buildMain) [ "-DBUILD_INFO_MAIN=OFF" ]);
}
