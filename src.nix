self:
let
  inherit (self.packages.x86_64-linux) pkgs lib;
in
{
  nvhpc = {
    src = pkgs.fetchurl {
      url = "https://developer.download.nvidia.com/hpc-sdk/25.7/nvhpc_2025_257_Linux_x86_64_cuda_12.9.tar.gz";
      sha256 = "08rrn2cgx6d4pc0ir6qj5hf0m5zvrj5gph9advg1f47pn3r8ws2c";
    };
    mpi = pkgs.requireFile {
      name = "openmpi-gitclone.tar.gz";
      # download from https://content.mellanox.com/hpc/hpc-x/v2.23/hpcx-v2.23-gcc-doca_ofed-ubuntu24.04-cuda12-x86_64.tbz
      # nix-prefetch-url file://$(pwd)/openmpi-gitclone.tar.gz
      sha256 = "1lx5gld4ay9p327hdlqsi72911cfm6s5v3yabjlmwr7sb27y8151";
      message = "Source file not found.";
    };
    version = "25.7";
    cudaVersion = "12.9";
  };
  iso = {
    nixos = pkgs.fetchurl {
      url =
        "https://releases.nixos.org/nixos/24.11/nixos-24.11.714826.04ef94c4c158/"
        + "nixos-minimal-24.11.714826.04ef94c4c158-x86_64-linux.iso";
      sha256 = "12zkmlmvvp6g3syb347q4ffhdavfs3hz2qxvvlgrim6k0kzz436k";
    };
    netboot = pkgs.fetchurl {
      url = "https://boot.netboot.xyz/ipxe/netboot.xyz.iso";
      sha256 = "0h7shj8gm3kzh7d7bcwygkp3fz5mac957accqhr9dhpjaj9dsmlr";
    };
  };
  vasp = {
    vasp = pkgs.requireFile {
      name = "vasp.6.4.3.tgz";
      # nix-prefetch-url file://$(pwd)/vasp.6.4.3.tgz
      sha256 = "1x14dixils77rr4c6yqmxkvyzgfz6906badsw2shksd3y9ryfc7y";
      message = "Source file not found.";
    };
    vtst = {
      patch = pkgs.fetchzip {
        url = "http://theory.cm.utexas.edu/code/vtstcode-204.tgz";
        sha256 = "00qpqiabl568fwqjnmwqwr0jwg7s56xd9lv9lw8q4qxqy19cpg62";
      };
      script = pkgs.fetchzip {
        url = "http://theory.cm.utexas.edu/code/vtstscripts.tgz";
        sha256 = "0wz9sw72w5gydvavm6sbcfssvvdiw8gh8hs0d0p0b23839dw4w6j";
      };
    };
  };
  misskey = {
    re2 = pkgs.fetchurl {
      url = "https://github.com/uhop/node-re2/releases/download/1.24.1/linux-x64-137.br";
      sha256 = "1zvr93vshl10q1fwax3rf58j6j81xv79yc3iwb6xhlpm1z2b0lb9";
    };
    extraIntegritySha256 = { };
  };
  lumerical = {
    lumerical = pkgs.requireFile {
      name = "lumerical.zip";
      sha256 = "03nfacykfzal29jdmygrgkl0fqsc3yqp4ig86h1h9sirci87k94c";
      hashMode = "recursive";
      message = "Source not found.";
    };
    licenseManager = {
      crack = pkgs.requireFile {
        name = "crack";
        sha256 = "1a1k3nlaidi0kk2xxamb4pm46iiz6k3sxynhd65y8riylrkck3md";
        hashMode = "recursive";
        message = "Source file not found.";
      };
      src = pkgs.requireFile {
        name = "licenseManager";
        sha256 = "1h93r0bb37279dzghi3k2axf0b8g0mgacw0lcww5j3sx0sqjbg4l";
        hashMode = "recursive";
        message = "Source file not found.";
      };
      image = "6803f9562b941c23db81a2eae5914561f96fa748536199a010fe6f24922b2878";
      imageFile = pkgs.requireFile {
        name = "lumericalLicenseManager.tar";
        sha256 = "ftEZADv8Mgo5coNKs+gxPZPl/YTV3FMMgrF3wUIBEiQ=";
        message = "Source not found.";
      };
      license = pkgs.requireFile {
        name = "license";
        sha256 = "07rwin14py6pl1brka7krz7k2g9x41h7ks7dmp1lxdassan86484";
        message = "Source file not found.";
      };
      sifImageFile = pkgs.requireFile {
        name = "lumericalLicenseManager.sif";
        sha256 = "i0HGLiRWoKuQYYx44GBkDBbyUvFLbfFShi/hx7KBSuU=";
        message = "Source file not found.";
      };
    };
  };
  vesta = rec {
    version = "3.5.8";
    src = pkgs.fetchurl {
      url = "https://jp-minerals.org/vesta/archives/${version}/VESTA-gtk3.tar.bz2";
      sha256 = "1y4dhqhk0jy7kbkkx2c6lsrm5lirn796mq67r5j1s7xkq8jz1gkq";
    };
    desktopFile = pkgs.fetchurl {
      url = "https://aur.archlinux.org/cgit/aur.git/plain/VESTA.desktop?h=vesta&id=4fae08afc37ee0fd88d14328cf0d6b308fea04d1";
      sha256 = "Tq4AzQgde2KIWKA1k6JlxvdphGG9JluHMZjVw0fBUeQ=";
    };
  };
  pslist = {
    version = "1.4.0";
    src = pkgs.fetchzip {
      url = "https://launchpad.net/ubuntu/+archive/primary/+sourcefiles/pslist/1.4.0-6/pslist_1.4.0.orig.tar.xz";
      sha256 = "1sp1h7ccniz658ms331npffpa9iz8llig43d9mlysll420nb3xqv";
    };
  };
  vaspkit = rec {
    version = "1.5.1";
    potcar = pkgs.requireFile {
      name = "POTCAR";
      sha256 = "01adpp9amf27dd39m8svip3n6ax822vsyhdi6jn5agj13lis0ln3";
      hashMode = "recursive";
      message = "POTCAR not found.";
    };
    vaspkit = pkgs.fetchurl {
      url = "mirror://sourceforge/vaspkit/Binaries/vaspkit.${version}.linux.x64.tar.gz";
      sha256 = "1cbj1mv7vx18icwlk9d2vfavsfd653943xg2ywzd8b7pb43xrfs1";
    };
  };
  mathematica = pkgs.mathematica.src;
  oneapi = {
    src = pkgs.fetchurl {
      url =
        "https://registrationcenter-download.intel.com/akdlm/IRC_NAS/2cf9c083-82b5-4a8f-a515-c599b09dcefc/"
        + "intel-oneapi-hpc-toolkit-2025.1.1.40_offline.sh";
      sha256 = "1qjy9dsnskwqsk66fm99b3cch1wp3rl9dx7y884p3x5kwiqdma2x";
    };
    version = "2025.1";
    fullVersion = "2025.1.1.40";
    components = [
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
  wechat = pkgs.dockerTools.pullImage {
    imageName = "nickrunning/wechat-selkies";
    imageDigest = "sha256:387eed17951aca783c9125ade88640702174d5fd676b0cffafaa474a20a9d416";
    hash = "sha256-RkjQsoJ3Py/n9ZJBdBnX9VuaqEJHy9wn4tHZQgCWUg0=";
    finalImageName = "nickrunning/wechat-selkies";
    finalImageTag = "0.0.12";
  };
  rsshub = pkgs.dockerTools.pullImage {
    imageName = "diygod/rsshub";
    imageDigest = "sha256:67fab5d669cf7060046ec8940f148e27b4adc425e8659a6076050516af32bc69";
    hash = "sha256-VSQ/5dZy2OsFnu5VryeHY4OT+RmNHV44G9iBDEwZOpA=";
    finalImageName = "rsshub";
    finalImageTag = "latest";
  };
  atat = pkgs.fetchurl {
    url = "https://axelvandewalle.github.io/www-avdw/atat/atat3_50.tar.gz";
    sha256 = "14sblzqsi5bxfhsjbq256bc2gfd7zrxyf5za0iaw77b592ppjg3m";
  };
  atomkit = pkgs.fetchurl {
    url = "mirror://sourceforge/atomkit/Binaries/atomkit.0.9.0.linux.x64.tar.gz";
    sha256 = "0y9z7wva7zikh83w9q431lgn3bqkh1v5w6iz90dwc75wqwk0w5jr";
  };
  btrfs = {
    "6.18" = {
      patch = pkgs.fetchurl {
        url = "https://github.com/kakra/linux/pull/40.patch";
        sha256 = "02q3x64rdyj6nx7jdknlg7x69v10xxbm0ry2xbgr069dfdm2w1ya";
      };
      structuredExtraConfig = {
        BTRFS_ALLOCATOR_HINTS = lib.kernel.yes;
        BTRFS_READ_POLICIES = lib.kernel.yes;
      };
    };
  };
  # download include from /opt/ibm/lsfsuite/lsf/10.1/include into lsf/include
  # download lib from /opt/ibm/lsfsuite/lsf/10.1/linux2.6-glibc2.3-x86_64/lib into lsf/lib and only preserve .so
  lsf = pkgs.requireFile {
    name = "lsf";
    sha256 = "0rij4xx705yj1vr5jd31hb8izmb35vkrdql0850qc5cn30jnkf4l";
    hashMode = "recursive";
    message = "lsf not found.";
  };
  pyrho = pkgs.fetchFromGitHub {
    owner = "materialsproject";
    repo = "pyrho";
    tag = "v0.5.1";
    hash = "sha256-O4IZusn9/tDhX5NgRs+CpfQ17MYS535fXi8mPHfh9kc=";
  };
  mp-api = pkgs.fetchFromGitHub {
    owner = "materialsproject";
    repo = "api";
    tag = "v0.46.0";
    hash = "sha256-vBYiMn+QOHhPbQldpzyswE1F539zVztBEPgfSBjvlEg=";
  };
  emmet = pkgs.fetchFromGitHub {
    owner = "materialsproject";
    repo = "emmet";
    tag = "v0.86.4";
    hash = "sha256-96f4Vws4jg+zuUO4xHYl07B+3p4WqNbeoNj5/ej9qB8=";
  };
  pymatgen-io-validation = rec {
    version = "0.1.2";
    src = pkgs.fetchPypi {
      pname = "pymatgen_io_validation";
      inherit version;
      hash = "sha256-dmMoeKsiaTVgktq1uuCMj0JBjD4V1GEPTrME8BAufyQ=";
    };
  };
  pubchempy = rec {
    version = "1.0.5";
    src = pkgs.fetchPypi {
      pname = "pubchempy";
      inherit version;
      hash = "sha256-CPCyqCpcql1h4Uk11lXaVUYC17Vob+Zhq1hMiC//9iM=";
    };
  };
  shakenbreak = rec {
    version = "3.4.4";
    src = pkgs.fetchPypi {
      pname = "shakenbreak";
      inherit version;
      hash = "sha256-Tc4TUmYM8Gfnws6N5cUMIQzoddUHXNr4gKjBKe9YPiE=";
    };
  };
  cmcrameri = rec {
    version = "1.9";
    src = pkgs.fetchPypi {
      pname = "cmcrameri";
      inherit version;
      hash = "sha256-Vvr5t/U+sD/tRQE3vsfcJcGFSSnXuEG5x1YW/Cw1dkA=";
    };
  };
  doped = rec {
    version = "3.2.1";
    src = pkgs.fetchPypi {
      pname = "doped";
      inherit version;
      hash = "sha256-3dyS1+n4bca5M2YWUnwZgcK3I0VyVlroPWhZajb8onI=";
    };
  };
  hiphive = rec {
    version = "1.5";
    src = pkgs.fetchPypi {
      pname = "hiphive";
      inherit version;
      hash = "sha256-qBYmhiZa7YjPpq0nIfOWKRAlJRAIeUhFMMt8JSaaw4Y=";
    };
  };
  trainstation = rec {
    version = "1.2";
    src = pkgs.fetchPypi {
      pname = "trainstation";
      inherit version;
      hash = "sha256-4s2hcWoJ+YkwqjRkC9sqwF5J5nWv5Ul52BZX8/rDfZs=";
    };
  };
  pymatgen-analysis-defects = rec {
    version = "2026.3.20";
    src = pkgs.fetchPypi {
      pname = "pymatgen_analysis_defects";
      inherit version;
      hash = "sha256-rc9GR1F0G9p7OYHnx+ZDEz83399WR8AIEtTCLg8uIho=";
    };
  };
  phono3py = rec {
    version = "3.31.1";
    src = pkgs.fetchPypi {
      pname = "phono3py";
      inherit version;
      hash = "sha256-5j9Wj8cl6s8ZOew0LLiy3kOD9PgcvzQQWoSn3+rHuUk=";
    };
  };
  tailscaleOfficialDerp = pkgs.fetchurl {
    url = "https://controlplane.tailscale.com/derpmap/default";
    sha256 = "0hgs6aq9fcbz2pb6380jzcb0ikx6h4122n5icx2zqbflb2j2in4l";
  };
  dockerhub-mcp = rec {
    pname = "dockerhub-mcp";
    version = "1.0.0";
    src = pkgs.fetchFromGitHub {
      owner = "docker";
      repo = "hub-mcp";
      rev = "ad806e2cab0489a296aec0f32f3d3eea807d65c2";
      hash = "sha256-2Nhb2gAZa6P8HT9jL5DdEgnK/APUNETrXZmpwC69W1U=";
    };
    npmDeps = pkgs.fetchNpmDeps {
      name = "${pname}-${version}-npm-deps";
      inherit src;
      hash = "sha256-di/EDkHKQrUySc5wtyK2z/nqwAT1UEymx69bVPf+oaM=";
    };
  };
  models = {
    embed = pkgs.fetchurl {
      url = "https://huggingface.co/ggml-org/bge-m3-Q8_0-GGUF/resolve/main/bge-m3-q8_0.gguf";
      hash = "sha256-qkc9UfRRoi8Pzzm6MzDBS+04o4VxKxETRA9p30BHoXM=";
    };
    rerank = pkgs.fetchurl {
      url = "https://huggingface.co/gpustack/bge-reranker-v2-m3-GGUF/resolve/main/bge-reranker-v2-m3-Q8_0.gguf";
      hash = "sha256-pDx8mxGkwVF+W/lRUZYOFiHRty96STNksB44bPGqodM=";
    };
  };
  hindsight = pkgs.dockerTools.pullImage {
    imageName = "ghcr.io/vectorize-io/hindsight";
    imageDigest = "sha256:067636a79666807d804f1c35a4a34e0c916b52a1adeccb9bab003003bc127fc6";
    hash = "sha256-tqGQSYa1906ioavD8wLQD5HdTWgzvmC6Zw7SYKk+aeo=";
    finalImageName = "hindsight";
    finalImageTag = "latest";
  };
}
