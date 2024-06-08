{ stdenv, cmake, pkg-config, src, cpm-cmake, fmt, spdlog, catch2_3, cli11, ftxui, nlohmann_json, valijson }:
stdenv.mkDerivation
{
  name = "json2cpp";
  inherit src;
  buildInputs = [ fmt spdlog catch2_3 cli11 ftxui nlohmann_json nlohmann_json valijson ];
  nativeBuildInputs = [ cmake pkg-config cpm-cmake ];
  preConfigure =
  ''
    mkdir -p ${placeholder "out"}/share/cpm
    cp ${cpm-cmake}/share/cpm/CPM.cmake ${placeholder "out"}/share/cpm/CPM_0.38.1.cmake
  '';
  cmakeFlags = [ "-DCPM_USE_LOCAL_PACKAGES=1" "-DCPM_SOURCE_CACHE=${placeholder "out"}/share" ];
}
