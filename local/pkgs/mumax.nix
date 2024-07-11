{ buildGoModule, cudatoolkit, src, config, cudaCapabilities ? config.cudaCapabilities, gcc, makeWrapper }:
# TODO: use addDriverRunpath
buildGoModule
{
  name = "mumax";
  inherit src;
  vendorHash = null;
  nativeBuildInputs = [ cudatoolkit gcc makeWrapper ];
  CUDA_CC = builtins.concatStringsSep " " cudaCapabilities;
  CPATH = "${cudatoolkit}/include";
  LIBRARY_PATH = "${cudatoolkit}/lib/stubs";
  doCheck = false;
  postInstall =
  ''
    rm $out/bin/{doc,test}
    for i in $out/bin/*; do
      if [ -f $i ]; then
        wrapProgram $i --prefix LD_LIBRARY_PATH ":" "/run/opengl-driver/lib:${cudatoolkit}/lib"
      fi
    done
  '';
}
