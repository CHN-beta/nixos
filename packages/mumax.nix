{ buildGoModule, cudaPackages, src, config, cudaCapabilities ? config.cudaCapabilities, makeWrapper }:
# TODO: use addDriverRunpath
buildGoModule
{
  name = "mumax";
  inherit src;
  vendorHash = null;
  buildInputs = with cudaPackages; [ libcufft libcurand cuda_cudart cuda_nvcc ];
  nativeBuildInputs = [ cudaPackages.cuda_nvcc makeWrapper ];
  CUDA_CC = builtins.concatStringsSep " " cudaCapabilities;
  doCheck = false;
  postInstall =
  ''
    rm $out/bin/{doc,test}
    for i in $out/bin/*; do
      if [ -f $i ]; then
        wrapProgram $i --prefix LD_LIBRARY_PATH ":" "/run/opengl-driver/lib"
      fi
    done
  '';
}
