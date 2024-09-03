inputs: rec
{
  vesta = inputs.pkgs.callPackage ./vesta.nix {};
  rsshub = inputs.pkgs.callPackage ./rsshub.nix { inherit mkPnpmPackage; src = inputs.topInputs.rsshub; };
  misskey = inputs.pkgs.callPackage ./misskey.nix { inherit mkPnpmPackage; src = inputs.topInputs.misskey; };
  mk-meili-mgn = inputs.pkgs.callPackage ./mk-meili-mgn.nix {};
  vaspkit = inputs.pkgs.callPackage ./vaspkit.nix { inherit (inputs.localLib) attrsToList; };
  v-sim = inputs.pkgs.callPackage ./v-sim.nix { src = inputs.topInputs.v-sim; };
  concurrencpp = inputs.pkgs.callPackage ./concurrencpp.nix { src = inputs.topInputs.concurrencpp; };
  eigengdb = inputs.pkgs.python3Packages.callPackage ./eigengdb.nix {};
  nodesoup = inputs.pkgs.callPackage ./nodesoup.nix { src = inputs.topInputs.nodesoup; };
  matplotplusplus = inputs.pkgs.callPackage ./matplotplusplus.nix { src = inputs.topInputs.matplotplusplus; };
  zpp-bits = inputs.pkgs.callPackage ./zpp-bits.nix { src = inputs.topInputs.zpp-bits; };
  eigen = inputs.pkgs.callPackage ./eigen.nix { src = inputs.topInputs.eigen; };
  nameof = inputs.pkgs.callPackage ./nameof.nix { src = inputs.topInputs.nameof; };
  pslist = inputs.pkgs.callPackage ./pslist.nix {};
  glad = inputs.pkgs.callPackage ./glad.nix {};
  yoga-support = inputs.pkgs.callPackage ./yoga-support.nix {};
  tgbot-cpp = inputs.pkgs.callPackage ./tgbot-cpp.nix { src = inputs.topInputs.tgbot-cpp; };
  mirism = inputs.pkgs.callPackage ./mirism.nix
  {
    inherit cppcoro nameof tgbot-cpp date;
    nghttp2 = inputs.pkgs.callPackage "${inputs.topInputs."nixpkgs-23.05"}/pkgs/development/libraries/nghttp2"
      { enableAsioLib = true; stdenv = inputs.pkgs.gcc12Stdenv; };
    stdenv = inputs.pkgs.gcc12Stdenv;
  };
  cppcoro = inputs.pkgs.callPackage ./cppcoro { src = inputs.topInputs.cppcoro; };
  date = inputs.pkgs.callPackage ./date.nix { src = inputs.topInputs.date; };
  esbonio = inputs.pkgs.python3Packages.callPackage ./esbonio.nix {};
  pix2tex = inputs.pkgs.python3Packages.callPackage ./pix2tex {};
  pyreadline3 = inputs.pkgs.python3Packages.callPackage ./pyreadline3.nix {};
  torchdata = inputs.pkgs.python3Packages.callPackage ./torchdata.nix {};
  torchtext = inputs.pkgs.python3Packages.callPackage ./torchtext.nix { inherit torchdata; };
  blurred-wallpaper = inputs.pkgs.callPackage ./blurred-wallpaper.nix { src = inputs.topInputs.blurred-wallpaper; };
  slate = inputs.pkgs.callPackage ./slate.nix { src = inputs.topInputs.slate; };
  nvhpc = inputs.pkgs.callPackage ./nvhpc.nix {};
  lmod = inputs.pkgs.callPackage ./lmod.nix { src = inputs.topInputs.lmod; };
  vasp = rec
  {
    src = inputs.pkgs.callPackage ./vasp/source.nix {};
    gnu = inputs.pkgs.callPackage ./vasp/gnu
    {
      inherit (inputs.pkgs.llvmPackages) openmp;
      inherit src;
      hdf5 = inputs.pkgs.hdf5.override { mpiSupport = true; fortranSupport = true; cppSupport = false; };
    };
    nvidia = inputs.pkgs.callPackage ./vasp/nvidia
      { inherit lmod nvhpc vtst src; hdf5 = hdf5-nvhpc; };
    intel = inputs.pkgs.callPackage ./vasp/intel
      { inherit lmod oneapi vtst src; hdf5 = hdf5-oneapi; };
    hdf5-nvhpc = inputs.pkgs.callPackage ./vasp/hdf5-nvhpc { inherit lmod nvhpc; inherit (inputs.pkgs.hdf5) src; };
    hdf5-oneapi = inputs.pkgs.callPackage ./vasp/hdf5-oneapi { inherit lmod oneapi; inherit (inputs.pkgs.hdf5) src; };
    vtst = (inputs.pkgs.callPackage ./vasp/vtst.nix {});
    vtstscripts = inputs.pkgs.callPackage ./vasp/vtstscripts.nix {};
  };
  # TODO: use other people packaged hpc version
  oneapi = inputs.pkgs.callPackage ./oneapi.nix {};
  mumax = inputs.pkgs.callPackage ./mumax.nix { src = inputs.topInputs.mumax; };
  kylin-virtual-keyboard = inputs.pkgs.libsForQt5.callPackage ./kylin-virtual-keyboard.nix
    { src = inputs.topInputs.kylin-virtual-keyboard; };
  biu = inputs.pkgs.callPackage ./biu
  {
    inherit nameof zpp-bits tgbot-cpp;
    stdenv = inputs.pkgs.gcc14Stdenv;
    fmt = inputs.pkgs.fmt_11.overrideAttrs (prev: { patches = prev.patches or [] ++ [ ./biu/fmt.patch ]; });
  };
  zxorm = inputs.pkgs.callPackage ./zxorm.nix { src = inputs.topInputs.zxorm; };
  hpcstat = inputs.pkgs.callPackage ./hpcstat
    { inherit sqlite-orm date biu openxlsx; stdenv = inputs.pkgs.gcc14Stdenv; };
  openxlsx = inputs.pkgs.callPackage ./openxlsx.nix { src = inputs.topInputs.openxlsx; };
  sqlite-orm = inputs.pkgs.callPackage ./sqlite-orm.nix { src = inputs.topInputs.sqlite-orm; };
  mkPnpmPackage = inputs.pkgs.callPackage ./mkPnpmPackage.nix {};
  sbatch-tui = inputs.pkgs.callPackage ./sbatch-tui { inherit biu; stdenv = inputs.pkgs.gcc14Stdenv; };
  ufo = inputs.pkgs.callPackage ./ufo
  {
    inherit concurrencpp biu matplotplusplus zpp-bits;
    tbb = inputs.pkgs.tbb_2021_11;
    stdenv = inputs.pkgs.gcc14Stdenv;
  };
  chn-bsub = inputs.pkgs.callPackage ./chn-bsub { inherit biu; };
  winjob = inputs.pkgs.callPackage ./winjob { stdenv = inputs.pkgs.gcc14Stdenv; };
  sockpp = inputs.pkgs.callPackage ./sockpp.nix { src = inputs.topInputs.sockpp; };
  git-lfs-transfer = inputs.pkgs.callPackage ./git-lfs-transfer.nix { src = inputs.topInputs.git-lfs-transfer; };
  py4vasp = inputs.pkgs.callPackage ./py4vasp.nix { src = inputs.topInputs.py4vasp; };

  fromYaml = content: builtins.fromJSON (builtins.readFile
    (inputs.pkgs.runCommand "toJSON" {}
      "${inputs.pkgs.remarshal}/bin/yaml2json ${builtins.toFile "content.yaml" content} $out"));
}
