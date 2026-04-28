inputs: rec
{
  vesta = inputs.pkgs.callPackage ./vesta.nix { src = inputs.flakeInputs.self.src.vesta; };
  misskey = inputs.pkgs.callPackage ./misskey.nix
  {
    inherit mkPnpmPackage;
    src = inputs.flakeInputs.misskey;
    extraIntegritySha256 = inputs.flakeInputs.self.src.misskey;
  };
  vaspkit = inputs.pkgs.callPackage ./vaspkit.nix { src = inputs.flakeInputs.self.src.vaspkit; };
  v-sim = inputs.pkgs.callPackage ./v-sim.nix { src = inputs.flakeInputs.v-sim; };
  concurrencpp = inputs.pkgs.callPackage ./concurrencpp.nix { src = inputs.flakeInputs.concurrencpp; };
  matplotplusplus = inputs.pkgs.callPackage ./matplotplusplus.nix { src = inputs.flakeInputs.matplotplusplus; };
  zpp-bits = inputs.pkgs.callPackage ./zpp-bits.nix { src = inputs.flakeInputs.zpp-bits; };
  nameof = inputs.pkgs.callPackage ./nameof.nix { src = inputs.flakeInputs.nameof; };
  pslist = inputs.pkgs.callPackage ./pslist.nix { src = inputs.flakeInputs.self.src.pslist; };
  tgbot-cpp = inputs.pkgs.callPackage ./tgbot-cpp.nix { src = inputs.flakeInputs.tgbot-cpp; };
  mirism-old = inputs.pkgs.pkgs-2305.callPackage ./mirism-old.nix
  {
    inherit cppcoro nameof date;
    src = inputs.flakeInputs.mirism-old;
    nghttp2 = inputs.pkgs.pkgs-2305.nghttp2.override { enableAsioLib = true; };
  };
  cppcoro = inputs.pkgs.callPackage ./cppcoro { src = inputs.flakeInputs.cppcoro; };
  date = inputs.pkgs.callPackage ./date.nix { src = inputs.flakeInputs.date; };
  vasp =
  {
    gnu = inputs.pkgs.callPackage ./vasp/gnu
    {
      inherit (inputs.pkgs.llvmPackages) openmp;
      src = inputs.flakeInputs.self.src.vasp.vasp;
      hdf5 = inputs.pkgs.hdf5.override { mpiSupport = true; fortranSupport = true; cppSupport = false; };
    };
    nvidia = inputs.pkgs.callPackage ./vasp/nvidia
      { inherit (nvhpcPackages) stdenv hdf5 mpi; src = inputs.flakeInputs.self.src.vasp; };
    intel = inputs.pkgs.callPackage ./vasp/intel
    {
      src = inputs.flakeInputs.self.src.vasp;
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
    };
    vtst = inputs.pkgs.callPackage ./vasp/vtst.nix { src = inputs.flakeInputs.self.src.vasp.vtst.script; };
  };
  mumax = inputs.pkgs.callPackage ./mumax.nix { src = inputs.flakeInputs.mumax; };
  biu = inputs.pkgs.callPackage ./biu
  {
    inherit nameof zpp-bits tgbot-cpp concurrencpp pocketfft;
    boost = inputs.pkgs.boost188;
    fmt = inputs.pkgs.fmt_11.overrideAttrs (prev: { patches = prev.patches or [] ++ [ ./biu/fmt.patch ]; });
  };
  hpcstat = inputs.pkgs.callPackage ./hpcstat { inherit sqlite-orm date biu openxlsx; };
  openxlsx = inputs.pkgs.callPackage ./openxlsx.nix { src = inputs.flakeInputs.openxlsx; };
  sqlite-orm = inputs.pkgs.callPackage ./sqlite-orm.nix { src = inputs.flakeInputs.sqlite-orm; };
  mkPnpmPackage = inputs.pkgs.callPackage ./mkPnpmPackage.nix {};
  sbatch-tui = inputs.pkgs.callPackage ./sbatch-tui { inherit biu; };
  ufo = inputs.pkgs.callPackage inputs.flakeInputs.ufo { inherit biu matplotplusplus; };
  chn-bsub = inputs.pkgs.callPackage ./chn-bsub { inherit biu; };
  pocketfft = inputs.pkgs.callPackage ./pocketfft.nix { src = inputs.flakeInputs.pocketfft; };
  vaspberry = inputs.pkgs.callPackage ./vaspberry.nix { src = inputs.flakeInputs.vaspberry; };
  nvhpcPackages = inputs.pkgs.lib.makeScope inputs.pkgs.newScope (final:
  {
    stdenv = inputs.pkgs.callPackage ./nvhpc/stdenv.nix { src = inputs.flakeInputs.self.src.nvhpc; };
    fmt = (inputs.pkgs.fmt.override { inherit (final) stdenv; }).overrideAttrs { doCheck = false; };
    hdf5 = (inputs.pkgs.hdf5-fortran.override { inherit (final) stdenv; cppSupport = false; }).overrideAttrs (prev:
    {
      patches = prev.patches or [] ++ [ ./nvhpc/hdf5.patch ];
      cmakeFlags = prev.cmakeFlags ++ [ "-DHDF5_ENABLE_NONSTANDARD_FEATURE_FLOAT16=OFF" ];
    });
    mpi = inputs.pkgs.callPackage ./nvhpc/mpi.nix
      { inherit (final) stdenv; src = inputs.flakeInputs.self.src.nvhpc.mpi; };
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
  stickerpicker = inputs.pkgs.python3Packages.callPackage ./stickerpicker.nix { src = inputs.flakeInputs.stickerpicker; };
  info = inputs.pkgs.callPackage ./info { inherit biu; };
  blog = inputs.pkgs.callPackage inputs.flakeInputs.blog
  {
    inherit (inputs.flakeInputs) hextra;
    buildProxy = inputs.pkgs.lib.mkBuildproxy ./blog-buildproxy.nix;
  };
  vm = inputs.pkgs.callPackage ./vm { inherit biu; };
  oneapiPackages = inputs.pkgs.lib.makeScope inputs.pkgs.newScope (final:
  {
    stdenv = inputs.pkgs.callPackage ./oneapi/stdenv.nix { src = inputs.flakeInputs.self.src.oneapi; inherit gccFull; };
    fmt = (inputs.pkgs.fmt.override { inherit (final) stdenv; }).overrideAttrs { doCheck = false; env.VERBOSE = "1"; };
  });
  lumerical =
  {
    lumerical = inputs.pkgs.callPackage ./lumerical/lumerical.nix
      { src = inputs.flakeInputs.self.src.lumerical.lumerical; };
    licenseManager = inputs.pkgs.callPackage ./lumerical/licenseManager.nix
      { inherit (inputs.flakeInputs.self.src.lumerical.licenseManager) src crack; };
    license = inputs.pkgs.callPackage ./lumerical/license.nix
      { src = inputs.flakeInputs.self.src.lumerical.licenseManager.license; };
  };
  speedtest = inputs.pkgs.callPackage ./speedtest.nix { src = inputs.flakeInputs.speedtest; };
  atat = inputs.pkgs.callPackage ./atat.nix { src = inputs.flakeInputs.self.src.atat; };
  atomkit = inputs.pkgs.callPackage ./atomkit.nix { src = inputs.flakeInputs.self.src.atomkit; };
  xinli = inputs.pkgs.callPackage ./xinli { inherit biu; };
  pybinding = inputs.pkgs.pkgs-2411.python310Packages.callPackage ./pybinding
  {
    src = inputs.flakeInputs.pybinding;
    buildProxy = inputs.pkgs.lib.mkBuildproxy ./pybinding/proxy.nix;
  };
  missgram = inputs.pkgs.callPackage ./missgram { inherit biu sqlgen; };
  sqlgen = inputs.pkgs.callPackage ./sqlgen.nix { src = inputs.flakeInputs.sqlgen; inherit reflectcpp; };
  reflectcpp = inputs.pkgs.callPackage ./reflectcpp.nix { src = inputs.flakeInputs.reflectcpp; };
  lsf = inputs.pkgs.callPackage ./lsf.nix { src = inputs.flakeInputs.self.src.lsf; };
  asmroner = inputs.pkgs.callPackage ./asmroner.nix { src = inputs.flakeInputs.asmroner; };
  pythonOverlay = python3Packages:
  {
    py4vasp = python3Packages.callPackage ./py4vasp.nix { src = inputs.flakeInputs.py4vasp; };
    phono3py = python3Packages.callPackage ./phono3py.nix { src = inputs.flakeInputs.phono3py; };
    brokenaxes = python3Packages.callPackage ./brokenaxes.nix { src = inputs.flakeInputs.brokenaxes; };
  };
  minibox = inputs.pkgs.callPackage ./minibox {};
  debug-kernel310-hang = inputs.pkgs.callPackage ./debug-kernel310-hang { boost = inputs.pkgs.boost188; };

  fromYaml = content: builtins.fromJSON (builtins.readFile
    (inputs.pkgs.runCommand "toJSON" {}
      "${inputs.pkgs.yj}/bin/yj < ${builtins.toFile "content.yaml" content} > $out"));
}
