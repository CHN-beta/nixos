{ inputs }: let inherit (inputs.self.packages.x86_64-linux) pkgs; inherit (inputs.nixpkgs) lib; in
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
      sha256 = "6GeOcugqElGPoPXeaWVpjcV5bCFxNLShGgN/sjsVzuI=";
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
        url = "http://theory.cm.utexas.edu/code/vtstcode-204.tgz";
        sha256 = "00qpqiabl568fwqjnmwqwr0jwg7s56xd9lv9lw8q4qxqy19cpg62";
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
  lumerical =
  {
    lumerical = pkgs.requireFile
    {
      name = "lumerical.zip";
      sha256 = "03nfacykfzal29jdmygrgkl0fqsc3yqp4ig86h1h9sirci87k94c";
      hashMode = "recursive";
      message = "Source not found.";
    };
    licenseManager =
    {
      crack = pkgs.requireFile
      {
        name = "crack";
        sha256 = "1a1k3nlaidi0kk2xxamb4pm46iiz6k3sxynhd65y8riylrkck3md";
        hashMode = "recursive";
        message = "Source file not found.";
      };
      src = pkgs.requireFile
      {
        name = "src";
        sha256 = "1h93r0bb37279dzghi3k2axf0b8g0mgacw0lcww5j3sx0sqjbg4l";
        hashMode = "recursive";
        message = "Source file not found.";
      };
      image = "6803f9562b941c23db81a2eae5914561f96fa748536199a010fe6f24922b2878";
      imageFile = pkgs.requireFile
      {
        name = "lumericalLicenseManager.tar";
        sha256 = "ftEZADv8Mgo5coNKs+gxPZPl/YTV3FMMgrF3wUIBEiQ=";
        message = "Source not found.";
      };
      license = pkgs.requireFile
      {
        name = "license";
        sha256 = "07rwin14py6pl1brka7krz7k2g9x41h7ks7dmp1lxdassan86484";
        message = "Source file not found.";
      };
      sifImageFile = pkgs.requireFile
      {
        name = "lumericalLicenseManager.sif";
        sha256 = "i0HGLiRWoKuQYYx44GBkDBbyUvFLbfFShi/hx7KBSuU=";
        message = "Source file not found.";
      };
    };
  };
  vesta = rec
  {
    version = "3.5.8";
    src = pkgs.fetchurl
    {
      url = "https://jp-minerals.org/vesta/archives/${version}/VESTA-gtk3.tar.bz2";
      sha256 = "1y4dhqhk0jy7kbkkx2c6lsrm5lirn796mq67r5j1s7xkq8jz1gkq";
    };
    desktopFile = pkgs.fetchurl
    {
      url = "https://aur.archlinux.org/cgit/aur.git/plain/VESTA.desktop?h=vesta&id=4fae08afc37ee0fd88d14328cf0d6b308fea04d1";
      sha256 = "Tq4AzQgde2KIWKA1k6JlxvdphGG9JluHMZjVw0fBUeQ=";
    };
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
    fullVersion = "2025.1.1.40";
    components =
    [
      "intel.oneapi.lin.dpcpp-cpp-common,v=2025.1.1+10"
      "intel.oneapi.lin.dpcpp-cpp-common.runtime,v=2025.1.1+10"
      "intel.oneapi.lin.ifort-compiler,v=2025.1.1+10"
      "intel.oneapi.lin.compilers-common.runtime,v=2025.1.1+10"
      "intel.oneapi.lin.mpi.runtime,v=2021.15.0+493"
      "intel.oneapi.lin.umf,v=0.10.0+355"
      "intel.oneapi.lin.tbb.runtime,v=2022.1.0+425"
      "intel.oneapi.lin.compilers-common,v=2025.1.1+10"
    ];
  };
  rsshub = pkgs.dockerTools.pullImage
  {
    imageName = "diygod/rsshub";
    imageDigest = "sha256:1f9d97263033752bf5e20c66a75e134e6045b6d69ae843c1f6610add696f8c22";
    hash = "sha256-zN47lhQc3EX28LmGF4N3rDUPqumwmhfGn1OpvBYd2Vw=";
    finalImageName = "rsshub";
    finalImageTag = "latest";
  };
  atat = pkgs.fetchurl
  {
    url = "https://axelvandewalle.github.io/www-avdw/atat/atat3_50.tar.gz";
    sha256 = "14sblzqsi5bxfhsjbq256bc2gfd7zrxyf5za0iaw77b592ppjg3m";
  };
  atomkit = pkgs.fetchurl
  {
    url = "mirror://sourceforge/atomkit/Binaries/atomkit.0.9.0.linux.x64.tar.gz";
    sha256 = "0y9z7wva7zikh83w9q431lgn3bqkh1v5w6iz90dwc75wqwk0w5jr";
  };
  guix = pkgs.fetchurl
  {
    url = "https://ci.guix.gnu.org/download/2857";
    name = "guix.iso";
    sha256 = "0xqabnay8wwqc1a96db8ix1a6bhvgm84s5is1q67rr432q7gqgd4";
  };
  peerBanHelper =
  {
    image = "ghostchu/peerbanhelper:v8.0.12";
    imageFile = pkgs.dockerTools.pullImage
    {
      imageName = "ghostchu/peerbanhelper";
      imageDigest = "sha256:fce7047795fe1e6d730ea2583b390ccc336e79eb2d8dae8114f4f63f00208879";
      hash = "sha256-7Z2ewDpGFXyvCze9HZ7KwFwn9o9R6Y4pjJDcr5Wmy1g=";
      finalImageName = "ghostchu/peerbanhelper";
      finalImageTag = "v8.0.12";
    };
  };
  btrfs =
  {
    "6.12" =
    {
      patch = pkgs.fetchurl
      {
        url = "https://github.com/kakra/linux/pull/36.patch";
        sha256 = "0wimihsvrxib6g23jcqdbvqlkqk6nbqjswfx9bzmpm1vlvzxj8m0";
      };
      structuredExtraConfig.BTRFS_EXPERIMENTAL = lib.kernel.yes;
    };
    "6.18" =
    {
      patch = pkgs.fetchurl
      {
        url = "https://github.com/kakra/linux/pull/40.patch";
        sha256 = "00k57gx5xmwsdr83qc24dwkiin1qcyl929262m9kix699g7fclga";
      };
      structuredExtraConfig = { BTRFS_ALLOCATOR_HINTS = lib.kernel.yes; BTRFS_READ_POLICIES = lib.kernel.yes; };
    };
  };
}
