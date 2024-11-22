{ inputs }: let inherit (inputs.self.packages.x86_64-linux) pkgs; in
{
  git-lfs-transfer = "sha256-V2cnWCyzxwxlOXXTB8Kz4X4VHvu0H/SqHBzPFwlp73o=";
  nvhpc =
  {
    src = pkgs.fetchurl
    {
      url = "https://developer.download.nvidia.com/hpc-sdk/24.11/nvhpc_2024_2411_Linux_x86_64_cuda_12.6.tar.gz";
      sha256 = "080rb89p2z98b75wqssvp3s8x6b5n0556d0zskh3cfapcb08lh1r";
    };
    version = "24.11";
  };
}
