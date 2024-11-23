{ inputs }: let inherit (inputs.self.packages.x86_64-linux) pkgs; in
{
  git-lfs-transfer = "sha256-V2cnWCyzxwxlOXXTB8Kz4X4VHvu0H/SqHBzPFwlp73o=";
  nvhpc =
  {
    src = pkgs.fetchurl
    {
      url = "https://developer.download.nvidia.com/hpc-sdk/ubuntu/amd64/nvhpc-24-11_24.11-0_amd64.deb";
      sha256 = "0xzfgdz7s8kzxmcm3k6n9nqd0isfzj23nxfq0y3ca9f046gp4zp3";
    };
    version = "24.11";
  };
}
