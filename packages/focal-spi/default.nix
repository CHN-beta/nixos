{ src }: { stdenv, kernel, kernelModuleMakeFlags }: stdenv.mkDerivation
{
  name = "focal_spi";
  inherit src;
  patches = [ ./FT9369.patch ];
  nativeBuildInputs = kernel.moduleBuildDependencies;
  setSourceRoot =
    ''
      export sourceRoot=$PWD/build
    '';
  # makeFlags = kernelModuleMakeFlags;
  makeFlags = kernelModuleMakeFlags ++ [
    "-C"
    "${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
    "M=$(pwd)"
  ];
  buildFlags = [ "modules" ];
  installFlags = [ "INSTALL_MOD_PATH=${placeholder "out"}" ];
  installTargets = [ "modules_install" ];
}
