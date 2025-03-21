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
    url = "https://releases.nixos.org/nixos/24.11/nixos-24.11.714826.04ef94c4c158/"
      + "nixos-minimal-24.11.714826.04ef94c4c158-x86_64-linux.iso";
    sha256 = "12zkmlmvvp6g3syb347q4ffhdavfs3hz2qxvvlgrim6k0kzz436k";
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
  huginn = pkgs.dockerTools.pullImage
  {
    imageName = "ghcr.io/huginn/huginn";
    imageDigest = "sha256:fdaa76b95534f3c3a799d527821681dd61b8b6fc24de0a7e109fc665b627f115";
    sha256 = "062c18360asnzl610n11vd46621cvkj26ay21l82f16r12k4qzwy";
    finalImageName = "huginn/huginn";
    finalImageTag = "latest";
  };
  misskey =
  {
    "https://github.com/aiscript-dev/aiscript-languageserver/releases/download/0.1.6/aiscript-dev-aiscript-languageserver-0.1.6.tgz" = "0092d5r67bhf4xkvrdn4a2rm1drjzy7b5sw8mi7hp4pqvpc20ylr";
    "https://github.com/misskey-dev/tabler-icons/archive/refs/tags/3.30.0-mi.1932+ab127beee.tar.gz" = "09aa34a02rdpcvrhl6xddzy173pg7pi9i551s692ggc3pq7fmdhw";
  };
  xmuvpn = pkgs.dockerTools.pullImage
  {
    imageName = "hagb/docker-easyconnect";
    imageDigest = "sha256:1c3a86e41c1d2425a4fd555d279deaec6ff1e3c2287853eb16d23c9cb6dc3409";
    sha256 = "1jpk2y46lnk0mi6ir7hdx0p6378p0v6qjbh6jm9a4cv5abw0mb2k";
    finalImageName = "hagb/docker-easyconnec";
    finalImageTag = "7.6.7";
  };
  lumerical =
  {
    crack = pkgs.requireFile
    {
      name = "crack";
      sha256 = "1a1k3nlaidi0kk2xxamb4pm46iiz6k3sxynhd65y8riylrkck3md";
      hashMode = "recursive";
    };
    licenseManager = pkgs.requireFile
    {
      name = "licenseManager";
      sha256 = "1h93r0bb37279dzghi3k2axf0b8g0mgacw0lcww5j3sx0sqjbg4l";
      hashMode = "recursive";
      message = "";
    };
    lumerical = pkgs.requireFile
    {
      name = "lumerical";
      sha256 = "03nfacykfzal29jdmygrgkl0fqsc3yqp4ig86h1h9sirci87k94c";
      hashMode = "recursive";
    };
  };
}
