{
  stdenv,
  src,
  cmake,
  pkg-config,
}:
stdenv.mkDerivation {
  name = "reflectcpp";
  inherit src;
  nativeBuildInputs = [
    cmake
    pkg-config
  ];
  cmakeFlags = [ "-DBUILD_SHARED_LIBS=ON" ];
}
