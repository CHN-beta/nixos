inputs: rec
{
  vesta = inputs.pkgs.callPackage ./vesta.nix { src = inputs.topInputs.self.src.vesta; };
  rsshub = inputs.pkgs.callPackage ./rsshub.nix { inherit mkPnpmPackage; src = inputs.topInputs.rsshub; };
  misskey = inputs.pkgs.callPackage ./misskey.nix
  {
    inherit mkPnpmPackage;
    src = inputs.topInputs.misskey;
    extraIntegritySha256 = inputs.topInputs.self.src.misskey;
  };
  vaspkit = inputs.pkgs.callPackage ./vaspkit.nix
  {
    inherit (inputs.localLib) attrsToList;
    src = inputs.topInputs.self.src.vaspkit;
  };
  v-sim = inputs.pkgs.callPackage ./v-sim.nix { src = inputs.topInputs.v-sim; };
  concurrencpp = inputs.pkgs.callPackage ./concurrencpp.nix { src = inputs.topInputs.concurrencpp; };
  matplotplusplus = inputs.pkgs.callPackage ./matplotplusplus.nix
  {
    src = inputs.topInputs.matplotplusplus;
    stdenv = inputs.pkgs.clang18Stdenv;
  };
  zpp-bits = inputs.pkgs.callPackage ./zpp-bits.nix { src = inputs.topInputs.zpp-bits; };
  nameof = inputs.pkgs.callPackage ./nameof.nix { src = inputs.topInputs.nameof; };
  pslist = inputs.pkgs.callPackage ./pslist.nix { src = inputs.topInputs.self.src.pslist; };
  tgbot-cpp = inputs.pkgs.callPackage ./tgbot-cpp.nix { src = inputs.topInputs.tgbot-cpp; };
  mirism-old = inputs.pkgs.callPackage ./mirism-old.nix
  {
    inherit cppcoro nameof tgbot-cpp date;
    src = inputs.topInputs.self.src.mirism-old;
    nghttp2 = inputs.pkgs.callPackage "${inputs.topInputs.nixpkgs-2305}/pkgs/development/libraries/nghttp2"
      { enableAsioLib = true; stdenv = inputs.pkgs.gcc12Stdenv; };
    stdenv = inputs.pkgs.gcc12Stdenv;
  };
  cppcoro = inputs.pkgs.callPackage ./cppcoro { src = inputs.topInputs.cppcoro; };
  date = inputs.pkgs.callPackage ./date.nix { src = inputs.topInputs.date; };
  blurred-wallpaper = inputs.pkgs.callPackage ./blurred-wallpaper.nix { src = inputs.topInputs.blurred-wallpaper; };
  slate = inputs.pkgs.callPackage ./slate.nix { src = inputs.topInputs.slate; };
  vasp =
  {
    gnu = inputs.pkgs.callPackage ./vasp/gnu
    {
      inherit (inputs.pkgs.llvmPackages) openmp;
      src = inputs.topInputs.self.src.vasp.vasp;
      hdf5 = inputs.pkgs.hdf5.override { mpiSupport = true; fortranSupport = true; cppSupport = false; };
    };
    nvidia = inputs.pkgs.callPackage ./vasp/nvidia
    {
      inherit (nvhpcPackages) stdenv hdf5 mpi;
      src = inputs.topInputs.self.src.vasp;
      wannier90 = inputs.pkgs.wannier90.overrideAttrs { buildFlags = [ "dynlib" ]; };
    };
    intel = inputs.pkgs.callPackage ./vasp/intel
    {
      src = inputs.topInputs.self.src.vasp;
      inherit (inputs.pkgs.intelPackages_2023) stdenv;
      mpi = inputs.pkgs.openmpi.override
      {
        inherit (inputs.pkgs.intelPackages_2023) stdenv;
        enableSubstitute = false;
      };
      hdf5 = inputs.pkgs.hdf5.override
      {
        inherit (inputs.pkgs.intelPackages_2023) stdenv;
        cppSupport = false;
        fortranSupport = true;
        enableShared = false;
        enableStatic = true;
      };
      wannier90 = inputs.pkgs.wannier90.overrideAttrs { buildFlags = [ "dynlib" ]; };
    };
    vtst = inputs.pkgs.callPackage ./vasp/vtst.nix { src = inputs.topInputs.self.src.vasp.vtst.script; };
  };
  mumax = inputs.pkgs.callPackage ./mumax.nix { src = inputs.topInputs.mumax; };
  biu = inputs.pkgs.callPackage ./biu
  {
    inherit nameof zpp-bits tgbot-cpp concurrencpp pocketfft;
    # TODO: report glaze bug to upstream
    inherit (inputs.pkgs.pkgs-2411) glaze;
    stdenv = inputs.pkgs.clang18Stdenv;
    boost = inputs.pkgs.boost186;
    fmt = inputs.pkgs.fmt_11.overrideAttrs (prev: { patches = prev.patches or [] ++ [ ./biu/fmt.patch ]; });
  };
  hpcstat = inputs.pkgs.callPackage ./hpcstat
    { inherit sqlite-orm date biu openxlsx; stdenv = inputs.pkgs.gcc14Stdenv; };
  openxlsx = inputs.pkgs.callPackage ./openxlsx.nix { src = inputs.topInputs.openxlsx; };
  sqlite-orm = inputs.pkgs.callPackage ./sqlite-orm.nix { src = inputs.topInputs.sqlite-orm; };
  mkPnpmPackage = inputs.pkgs.callPackage ./mkPnpmPackage.nix {};
  sbatch-tui = inputs.pkgs.callPackage ./sbatch-tui { inherit biu; stdenv = inputs.pkgs.clang18Stdenv; };
  ufo = inputs.pkgs.callPackage inputs.topInputs.ufo
  {
    inherit biu matplotplusplus;
    tbb = inputs.pkgs.tbb_2021_11;
    stdenv = inputs.pkgs.clang18Stdenv;
  };
  chn-bsub = inputs.pkgs.callPackage ./chn-bsub { inherit biu; };
  winjob = inputs.pkgs.callPackage ./winjob { stdenv = inputs.pkgs.gcc14Stdenv; };
  sockpp = inputs.pkgs.callPackage ./sockpp.nix { src = inputs.topInputs.sockpp; };
  py4vasp = inputs.pkgs.python3Packages.callPackage ./py4vasp.nix { src = inputs.topInputs.py4vasp; };
  pocketfft = inputs.pkgs.callPackage ./pocketfft.nix { src = inputs.topInputs.pocketfft; };
  spectroscopy = inputs.pkgs.callPackage ./spectroscopy.nix { src = inputs.topInputs.spectroscopy; };
  mirism = inputs.pkgs.callPackage ./mirism { inherit biu; stdenv = inputs.pkgs.clang18Stdenv; };
  vaspberry = inputs.pkgs.callPackage ./vaspberry.nix { src = inputs.topInputs.vaspberry; };
  nvhpcPackages = inputs.pkgs.lib.makeScope inputs.pkgs.newScope (final:
  {
    stdenv = inputs.pkgs.callPackage ./nvhpc/stdenv.nix { src = inputs.topInputs.self.src.nvhpc; };
    fmt = (inputs.pkgs.fmt.override { inherit (final) stdenv; }).overrideAttrs { doCheck = false; };
    hdf5 = inputs.pkgs.hdf5.override
      { inherit (final) stdenv; cppSupport = false; fortranSupport = true; enableShared = false; enableStatic = true; };
    mpi = inputs.pkgs.callPackage ./nvhpc/mpi.nix
      { inherit (final) stdenv; src = inputs.topInputs.self.src.nvhpc.mpi; };
  });
  gccFull = inputs.pkgs.symlinkJoin
  {
    name = "gcc";
    paths = with inputs.pkgs;
    [
      # wrapped binaries
      gcc gfortran glibc glibc.dev binutils iconv
      # not wrapped binaries
      gcc.cc gcc.cc.lib gfortran.cc gfortran.cc.lib binutils.bintools
    ];
  };
  stickerpicker = inputs.pkgs.python3Packages.callPackage ./stickerpicker.nix { src = inputs.topInputs.stickerpicker; };
  info = inputs.pkgs.callPackage ./info { inherit biu; stdenv = inputs.pkgs.clang18Stdenv; };
  blog = inputs.pkgs.callPackage inputs.topInputs.blog { inherit (inputs.topInputs) hextra; };
  phono3py = inputs.pkgs.python3Packages.callPackage ./phono3py.nix { src = inputs.topInputs.phono3py; };
  lumerical = inputs.pkgs.callPackage ./lumerical.nix { src = inputs.topInputs.self.src.lumerical.lumerical; };
  vm = inputs.pkgs.callPackage ./vm { inherit biu; stdenv = inputs.pkgs.clang18Stdenv; };
  oneapiPackages =
  {
    stdenv = inputs.pkgs.callPackage ./oneapi/stdenv.nix { src = inputs.topInputs.self.src.oneapi; };
  };

  fromYaml = content: builtins.fromJSON (builtins.readFile
    (inputs.pkgs.runCommand "toJSON" {}
      "${inputs.pkgs.yj}/bin/yj < ${builtins.toFile "content.yaml" content} > $out"));
}
