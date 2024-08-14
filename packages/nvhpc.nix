{
  version ? "24.7",
  stdenvNoCC, fetchurl, buildFHSEnv,
  gfortran, flock
}:
let
  versions =
  {
    "24.7" = "0lzqfpvdjl13vd4hd622jdpgl6zdrg0xs3zskfzvrgf55ym9885z";
    "24.1" = "1n0x1x7ywvr3623ylvrjagayn44mbvfas3c3062p7y3asmgjx697";
    "23.1" = "1xg933f4n1bw39y1x1vrjrbzpx36sbmjgvi332hfck3dbx0n982m";
  };
  releaseName = version:
    let versions = builtins.splitVersion version;
    in "nvhpc_20${builtins.elemAt versions 0}_${builtins.concatStringsSep "" versions}_Linux_x86_64_cuda_multi";
  builder = buildFHSEnv
  {
    name = "builder";
    targetPkgs = pkgs: with pkgs; [ coreutils ];
    extraBwrapArgs = [ "--bind" "$out" "$out" ];
  };
in stdenvNoCC.mkDerivation
{
  pname = "nvhpc";
  inherit version;
  src = fetchurl
  {
    url = "https://developer.download.nvidia.com/hpc-sdk/${version}/${releaseName version}.tar.gz";
    sha256 = versions.${version};
  };
  dontFixup = true;
  dontBuild = true;
  buildInputs = [ gfortran flock ];
  installPhase =
  ''
    export NVHPC_SILENT=true
    export NVHPC_INSTALL_TYPE=single
    export NVHPC_INSTALL_DIR=$out/share/nvhpc
    # $out should exist before bwrap
    mkdir -p $out
    ${builder}/bin/builder ./install
  '';
  requiredSystemFeatures = [ "gccarch-exact-${stdenvNoCC.hostPlatform.gcc.arch}" ];
}
