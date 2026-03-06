inputs: rec
{
  vesta = inputs.pkgs.callPackage ./vesta.nix { src = inputs.topInputs.self.src.vesta; };
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
  matplotplusplus = inputs.pkgs.callPackage ./matplotplusplus.nix { src = inputs.topInputs.matplotplusplus; };
  zpp-bits = inputs.pkgs.callPackage ./zpp-bits.nix { src = inputs.topInputs.zpp-bits; };
  nameof = inputs.pkgs.callPackage ./nameof.nix { src = inputs.topInputs.nameof; };
  pslist = inputs.pkgs.callPackage ./pslist.nix { src = inputs.topInputs.self.src.pslist; };
  tgbot-cpp = inputs.pkgs.callPackage ./tgbot-cpp.nix { src = inputs.topInputs.tgbot-cpp; };
  mirism-old = inputs.pkgs.pkgs-2305.callPackage ./mirism-old.nix
  {
    inherit cppcoro nameof date;
    src = inputs.topInputs.mirism-old;
    nghttp2 = inputs.pkgs.pkgs-2305.nghttp2.override { enableAsioLib = true; };
  };
  cppcoro = inputs.pkgs.callPackage ./cppcoro { src = inputs.topInputs.cppcoro; };
  date = inputs.pkgs.callPackage ./date.nix { src = inputs.topInputs.date; };
  vasp =
  {
    gnu = inputs.pkgs.callPackage ./vasp/gnu
    {
      inherit (inputs.pkgs.llvmPackages) openmp;
      src = inputs.topInputs.self.src.vasp.vasp;
      hdf5 = inputs.pkgs.hdf5.override { mpiSupport = true; fortranSupport = true; cppSupport = false; };
    };
    nvidia = inputs.pkgs.callPackage ./vasp/nvidia
      { inherit (nvhpcPackages) stdenv hdf5 mpi; src = inputs.topInputs.self.src.vasp; };
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
    };
    vtst = inputs.pkgs.callPackage ./vasp/vtst.nix { src = inputs.topInputs.self.src.vasp.vtst.script; };
  };
  mumax = inputs.pkgs.callPackage ./mumax.nix { src = inputs.topInputs.mumax; };
  biu = inputs.pkgs.callPackage ./biu
  {
    inherit nameof zpp-bits tgbot-cpp concurrencpp pocketfft;
    # TODO: report glaze bug to upstream
    inherit (inputs.pkgs.pkgs-2411) glaze;
    boost = inputs.pkgs.boost188;
    fmt = inputs.pkgs.fmt_11.overrideAttrs (prev: { patches = prev.patches or [] ++ [ ./biu/fmt.patch ]; });
  };
  hpcstat = inputs.pkgs.callPackage ./hpcstat
    { inherit sqlite-orm date biu openxlsx; stdenv = inputs.pkgs.gcc14Stdenv; };
  openxlsx = inputs.pkgs.callPackage ./openxlsx.nix { src = inputs.topInputs.openxlsx; };
  sqlite-orm = inputs.pkgs.callPackage ./sqlite-orm.nix { src = inputs.topInputs.sqlite-orm; };
  mkPnpmPackage = inputs.pkgs.callPackage ./mkPnpmPackage.nix {};
  sbatch-tui = inputs.pkgs.callPackage ./sbatch-tui { inherit biu; };
  ufo = inputs.pkgs.callPackage inputs.topInputs.ufo { inherit biu matplotplusplus; tbb = inputs.pkgs.tbb_2022; };
  chn-bsub = inputs.pkgs.callPackage ./chn-bsub { inherit biu; };
  pocketfft = inputs.pkgs.callPackage ./pocketfft.nix { src = inputs.topInputs.pocketfft; };
  vaspberry = inputs.pkgs.callPackage ./vaspberry.nix { src = inputs.topInputs.vaspberry; };
  nvhpcPackages = inputs.pkgs.lib.makeScope inputs.pkgs.newScope (final:
  {
    stdenv = inputs.pkgs.callPackage ./nvhpc/stdenv.nix { src = inputs.topInputs.self.src.nvhpc; };
    fmt = (inputs.pkgs.fmt.override { inherit (final) stdenv; }).overrideAttrs { doCheck = false; };
    hdf5 = (inputs.pkgs.hdf5-fortran.override { inherit (final) stdenv; cppSupport = false; }).overrideAttrs (prev:
    {
      patches = prev.patches or [] ++ [ ./nvhpc/hdf5.patch ];
      cmakeFlags = prev.cmakeFlags ++ [ "-DHDF5_ENABLE_NONSTANDARD_FEATURE_FLOAT16=OFF" ];
    });
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
  info = inputs.pkgs.callPackage ./info { inherit biu; };
  blog = inputs.pkgs.callPackage inputs.topInputs.blog
  {
    inherit (inputs.topInputs) hextra;
    buildProxy = inputs.pkgs.lib.mkBuildproxy ./blog-buildproxy.nix;
  };
  vm = inputs.pkgs.callPackage ./vm { inherit biu; };
  oneapiPackages = inputs.pkgs.lib.makeScope inputs.pkgs.newScope (final:
  {
    stdenv = inputs.pkgs.callPackage ./oneapi/stdenv.nix { src = inputs.topInputs.self.src.oneapi; inherit gccFull; };
    fmt = (inputs.pkgs.fmt.override { inherit (final) stdenv; }).overrideAttrs { doCheck = false; env.VERBOSE = "1"; };
  });
  lumerical =
  {
    lumerical = inputs.pkgs.callPackage ./lumerical/lumerical.nix
      { src = inputs.topInputs.self.src.lumerical.lumerical; };
    licenseManager = inputs.pkgs.callPackage ./lumerical/licenseManager.nix
      { inherit (inputs.topInputs.self.src.lumerical.licenseManager) src crack; };
    license = inputs.pkgs.callPackage ./lumerical/license.nix
      { src = inputs.topInputs.self.src.lumerical.licenseManager.license; };
  };
  speedtest = inputs.pkgs.callPackage ./speedtest.nix { src = inputs.topInputs.speedtest; };
  atat = inputs.pkgs.callPackage ./atat.nix { src = inputs.topInputs.self.src.atat; };
  atomkit = inputs.pkgs.callPackage ./atomkit.nix { src = inputs.topInputs.self.src.atomkit; };
  xinli = inputs.pkgs.callPackage ./xinli { inherit biu; };
  pybinding = inputs.pkgs.pkgs-2411.python310Packages.callPackage ./pybinding
  {
    src = inputs.topInputs.pybinding;
    buildProxy = inputs.pkgs.lib.mkBuildproxy ./pybinding/proxy.nix;
  };
  missgram = inputs.pkgs.callPackage ./missgram { inherit biu sqlgen; };
  sqlgen = inputs.pkgs.callPackage ./sqlgen.nix { src = inputs.topInputs.sqlgen; inherit reflectcpp; };
  reflectcpp = inputs.pkgs.callPackage ./reflectcpp.nix { src = inputs.topInputs.reflectcpp; };
  lsf = inputs.pkgs.callPackage ./lsf.nix { src = inputs.topInputs.self.src.lsf; };
  lazytyper = inputs.pkgs.callPackage ./lazytyper.nix {};
  asmroner = inputs.pkgs.callPackage ./asmroner.nix { src = inputs.topInputs.asmroner; };
  vocotype = inputs.pkgs.callPackage ./vocotype.nix { src = inputs.topInputs.vocotype; };
  pythonOverlay = python3Packages:
  {
    py4vasp = python3Packages.callPackage ./py4vasp.nix { src = inputs.topInputs.py4vasp; };
    phono3py = python3Packages.callPackage ./phono3py.nix { src = inputs.topInputs.phono3py; };
    brokenaxes = python3Packages.callPackage ./brokenaxes.nix { src = inputs.topInputs.brokenaxes; };
    funasr = python3Packages.callPackage ./funasr.nix { src = inputs.topInputs.funasr; };
    pytest-runner = python3Packages.callPackage ./pytest-runner.nix { src = inputs.topInputs.pytest-runner; };
    kaldiio = python3Packages.callPackage ./kaldiio.nix { src = inputs.topInputs.kaldiio; };
    modelscope = python3Packages.callPackage ./modelscope.nix { src = inputs.topInputs.modelscope; };
    pytorch-wpe = python3Packages.callPackage ./pytorch-wpe.nix { src = inputs.topInputs.pytorch-wpe; };
    torch-complex = python3Packages.callPackage ./torch-complex.nix { src = inputs.topInputs.torch-complex; };
    funasr-onnx = python3Packages.callPackage ./funasr-onnx {};
    kaldi-native-fbank = python3Packages.callPackage ./kaldi-native-fbank.nix
      { src = inputs.topInputs.kaldi-native-fbank; };
  };

  fromYaml = content: builtins.fromJSON (builtins.readFile
    (inputs.pkgs.runCommand "toJSON" {}
      "${inputs.pkgs.yj}/bin/yj < ${builtins.toFile "content.yaml" content} > $out"));
}
