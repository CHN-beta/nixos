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
    mpi = pkgs.requireFile
    {
      name = "openmpi-gitclone.tar.gz";
      # download from https://developer.nvidia.com/networking/hpc-x/eula?mrequest=downloads&mtype=hpc&mver=hpc-x&mname=v2.22/hpcx-v2.22-gcc-doca_ofed-ubuntu24.04-cuda12-x86_64.tbz
      # nix-prefetch-url file://$(pwd)/openmpi-gitclone.tar.gz
      sha256 = "05r5x6mgw2f2kcq9vhdkfj42panchzlbpns8qy57y4jsbmabwabi";
      message = "Source file not found.";
    };
    version = "24.11";
    cudaVersion = "12.6";
  };
  iso =
  {
    nixos = pkgs.fetchurl
    {
      url = "https://releases.nixos.org/nixos/24.11/nixos-24.11.714826.04ef94c4c158/"
        + "nixos-minimal-24.11.714826.04ef94c4c158-x86_64-linux.iso";
      sha256 = "12zkmlmvvp6g3syb347q4ffhdavfs3hz2qxvvlgrim6k0kzz436k";
    };
    netboot = pkgs.fetchurl
    {
      url = "https://boot.netboot.xyz/ipxe/netboot.xyz.iso";
      sha256 = "01hlslbi2i3jkzjwn24drhd2lriaqiwr9hb83r0nib9y1jvr3k5p";
    };
  };
  nglview = pkgs.fetchPypi
  {
    pname = "nglview";
    version = "3.1.2";
    hash = "sha256-f2cu+itsoNs03paOW1dmsUsbPa3iEtL4oIPGAKETRc4=";
  };
  vasp =
  {
    vasp = pkgs.requireFile
    {
      name = "vasp.6.4.3.tgz";
      # nix-prefetch-url file://$(pwd)/vasp.6.4.3.tgz
      sha256 = "1x14dixils77rr4c6yqmxkvyzgfz6906badsw2shksd3y9ryfc7y";
      message = "Source file not found.";
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
    lumerical = pkgs.requireFile
    {
      name = "lumerical.zip";
      sha256 = "03nfacykfzal29jdmygrgkl0fqsc3yqp4ig86h1h9sirci87k94c";
      hashMode = "recursive";
      message = "Source not found.";
    };
    licenseManagerImage = pkgs.requireFile
    {
      name = "lumericalLicenseManager.tar";
      sha256 = "VOtYMnDRUP74O2lAqMqBDLnXtNS8AhbBhyZBj/2aVoE=";
      message = "Source not found.";
    };
  };
  vesta =
  {
    version = "3.90.0a";
    src = pkgs.fetchurl
    {
      url = "https://jp-minerals.org/vesta/archives/testing/VESTA-gtk3-x86_64.tar.bz2";
      sha256 = "0bsvfr3409g2v1wgnfixpkjz1yzl2j1nlrk5a5rkdfs94rrvxzaa";
    };
    desktopFile = pkgs.fetchurl
    {
      url = "https://aur.archlinux.org/cgit/aur.git/plain/VESTA.desktop?h=vesta&id=4fae08afc37ee0fd88d14328cf0d6b308fea04d1";
      sha256 = "Tq4AzQgde2KIWKA1k6JlxvdphGG9JluHMZjVw0fBUeQ=";
    };
  };
  # nix-store --query --hash $(nix store add-path . --name 'mirism')
  mirism-old = pkgs.requireFile
  {
    name = "mirism";
    sha256 = "0f50pvdafhlmrlbf341mkp9q50v4ld5pbx92d2w1633f18zghbzf";
    hashMode = "recursive";
    message = "Source file not found.";
  };
  pslist =
  {
    version = "1.4.0";
    src = pkgs.fetchzip
    {
      url = "https://launchpad.net/ubuntu/+archive/primary/+sourcefiles/pslist/1.4.0-4/pslist_1.4.0.orig.tar.xz";
      sha256 = "1sp1h7ccniz658ms331npffpa9iz8llig43d9mlysll420nb3xqv";
    };
  };
  vaspkit = rec
  {
    version = "1.5.1";
    potcar = pkgs.requireFile
    {
      name = "POTCAR";
      sha256 = "01adpp9amf27dd39m8svip3n6ax822vsyhdi6jn5agj13lis0ln3";
      hashMode = "recursive";
      message = "POTCAR not found.";
    };
    vaspkit = pkgs.fetchurl
    {
      url = "mirror://sourceforge/vaspkit/Binaries/vaspkit.${version}.linux.x64.tar.gz";
      sha256 = "1cbj1mv7vx18icwlk9d2vfavsfd653943xg2ywzd8b7pb43xrfs1";
    };
  };
  mathematica = pkgs.mathematica.src;
}
