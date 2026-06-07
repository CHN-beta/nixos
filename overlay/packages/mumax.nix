{
  buildGoModule,
  cudaPackages,
  src,
  config,
  cudaCapabilities ? config.cudaCapabilities,
  autoAddDriverRunpath,
}:
buildGoModule {
  name = "mumax";
  inherit src;
  vendorHash = null;
  buildInputs = with cudaPackages; [
    libcufft
    libcurand
    cuda_cudart
    cuda_nvcc
  ];
  nativeBuildInputs = [
    cudaPackages.cuda_nvcc
    autoAddDriverRunpath
  ];
  env = {
    CUDA_CC = builtins.concatStringsSep " " cudaCapabilities;
    NIX_LDFLAGS = "-L${cudaPackages.cuda_cudart}/lib/stubs";
  };
  doCheck = false;
  postInstall = ''
    rm $out/bin/{doc,test}
  '';
}
