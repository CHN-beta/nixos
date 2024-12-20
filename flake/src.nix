{ inputs }: let inherit (inputs.self.packages.x86_64-linux) pkgs; in
{
  git-lfs-transfer = "sha256-qHQeBI2b8EmUinowixqEuR6iGwNYQy3pSc8iPVfJemE=";
  nvhpc =
  {
    src = pkgs.fetchurl
    {
      url = "https://developer.download.nvidia.com/hpc-sdk/ubuntu/amd64/nvhpc-24-11_24.11-0_amd64.deb";
      sha256 = "0xzfgdz7s8kzxmcm3k6n9nqd0isfzj23nxfq0y3ca9f046gp4zp3";
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
}
