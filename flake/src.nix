{ inputs }: let inherit (inputs.self.packages.x86_64-linux) pkgs; in
{
  nvhpc =
  {
    src = pkgs.fetchurl
    {
      url = "https://developer.download.nvidia.com/hpc-sdk/25.3/nvhpc_2025_253_Linux_x86_64_cuda_12.8.tar.gz";
      sha256 = "11gxb099yxrsxg9i6vydi7znxqiwqqkhgmg90s74qwpjyriqpbsp";
    };
    mpi = pkgs.requireFile
    {
      name = "openmpi-gitclone.tar.gz";
      # download from https://content.mellanox.com/hpc/hpc-x/v2.23/hpcx-v2.23-gcc-doca_ofed-ubuntu24.04-cuda12-x86_64.tbz
      # nix-prefetch-url file://$(pwd)/openmpi-gitclone.tar.gz
      sha256 = "1lx5gld4ay9p327hdlqsi72911cfm6s5v3yabjlmwr7sb27y8151";
      message = "Source file not found.";
    };
    version = "25.3";
    cudaVersion = "12.8";
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
        url = "http://theory.cm.utexas.edu/code/vtstcode-205.tgz";
        sha256 = "1cdlflc68jvl3wq01m4jh9chkls73nfl8684ffgkgkhlnajwbp8v";
      };
      script = pkgs.fetchzip
      {
        url = "http://theory.cm.utexas.edu/code/vtstscripts.tgz";
        sha256 = "0wz9sw72w5gydvavm6sbcfssvvdiw8gh8hs0d0p0b23839dw4w6j";
      };
    };
  };
  huginn = pkgs.dockerTools.pullImage
  {
    imageName = "ghcr.io/huginn/huginn";
    imageDigest = "sha256:68e2c7082cd51d417e5ce76fe123810e9d52f4ab2018569df5b74b913ed3bc64";
    sha256 = "0jpdysdphy1lyj6zwx2b1kbgs6bfnpkkx85mf1b9ybh3is6gaz6s";
    finalImageName = "ghcr.io/huginn/huginn";
    finalImageTag = "latest";
  };
  misskey = {};
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
    version = "3.90.5a";
    src = pkgs.fetchurl
    {
      url = "https://jp-minerals.org/vesta/archives/testing/VESTA-gtk3-x86_64.tar.bz2";
      sha256 = "0y277m2xvjyzx8hncc3ka73lir8x6x2xckjac9fdzg03z0jnpqzf";
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
      url = "https://launchpad.net/ubuntu/+archive/primary/+sourcefiles/pslist/1.4.0-6/pslist_1.4.0.orig.tar.xz";
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
  oneapi =
  {
      src = pkgs.fetchurl
    {
      url = "https://registrationcenter-download.intel.com/akdlm/IRC_NAS/2cf9c083-82b5-4a8f-a515-c599b09dcefc/"
        + "intel-oneapi-hpc-toolkit-2025.1.1.40_offline.sh";
      sha256 = "1qjy9dsnskwqsk66fm99b3cch1wp3rl9dx7y884p3x5kwiqdma2x";
    };
    version = "2025.1";
  };
}
