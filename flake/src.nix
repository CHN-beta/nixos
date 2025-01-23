{ inputs }: let inherit (inputs.self.packages.x86_64-linux) pkgs; in
{
  git-lfs-transfer = "sha256-qHQeBI2b8EmUinowixqEuR6iGwNYQy3pSc8iPVfJemE=";
  nvhpc =
  {
    src = pkgs.fetchurl
    {
      url = "https://developer.download.nvidia.com/hpc-sdk/24.11/nvhpc_2024_2411_Linux_x86_64_cuda_12.6.tar.gz";
      sha256 = "080rb89p2z98b75wqssvp3s8x6b5n0556d0zskh3cfapcb08lh1r";
    };
    version = "24.11";
    cudaVersion = "12.6";
  };
  iso = pkgs.fetchurl
  {
    url = "https://releases.nixos.org/nixos/24.11/nixos-24.11beta709057.0c582677378f"
      + "/nixos-plasma6-24.11beta709057.0c582677378f-x86_64-linux.iso";
    sha256 = "000wmfn6k5awqwsx9qldhdgahv4k09w4yzmvf0djs51qjdpha082";
  };
  nglview = pkgs.fetchPypi
  {
    pname = "nglview";
    version = "3.1.2";
    hash = "sha256-f2cu+itsoNs03paOW1dmsUsbPa3iEtL4oIPGAKETRc4=";
  };
  vtst =
  {
    patch = pkgs.fetchzip
    {
      url = "http://theory.cm.utexas.edu/code/vtstcode-204.tgz";
      sha256 = "00qpqiabl568fwqjnmwqwr0jwg7s56xd9lv9lw8q4qxqy19cpg62";
    };
    script = pkgs.fetchzip
    {
      url = "http://theory.cm.utexas.edu/code/vtstscripts.tgz";
      sha256 = "18gsw2850ig1mg4spp39i0ygfcwx0lqnamysn5whiax22m8d5z67";
    };
  };
  huginn = inputs.pkgs.dockerTools.pullImage
  {
    imageName = "ghcr.io/huginn/huginn";
    imageDigest = "sha256:fdaa76b95534f3c3a799d527821681dd61b8b6fc24de0a7e109fc665b627f115";
    sha256 = "062c18360asnzl610n11vd46621cvkj26ay21l82f16r12k4qzwy";
    finalImageName = "huginn/huginn";
    finalImageTag = "latest";
  };
}
