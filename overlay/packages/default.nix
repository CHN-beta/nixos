{ self, pkgs }:
rec {
  vesta = pkgs.callPackage ./vesta.nix { src = self.src.vesta; };
  misskey = pkgs.callPackage ./misskey.nix {
    inherit mkPnpmPackage;
    inherit (self.src.misskey) re2 extraIntegritySha256;
    src = self.inputs.misskey;
  };
  vaspkit = pkgs.callPackage ./vaspkit.nix { src = self.src.vaspkit; };
  v-sim = pkgs.callPackage ./v-sim.nix { src = self.inputs.v-sim; };
  concurrencpp = pkgs.callPackage ./concurrencpp.nix { src = self.inputs.concurrencpp; };
  matplotplusplus = pkgs.callPackage ./matplotplusplus.nix { src = self.inputs.matplotplusplus; };
  zpp-bits = pkgs.callPackage ./zpp-bits.nix { src = self.inputs.zpp-bits; };
  nameof = pkgs.callPackage ./nameof.nix { src = self.inputs.nameof; };
  pslist = pkgs.callPackage ./pslist.nix { src = self.src.pslist; };
  tgbot-cpp = pkgs.callPackage ./tgbot-cpp.nix { src = self.inputs.tgbot-cpp; };
  mirism-old = pkgs.pkgs2305.callPackage ./mirism-old.nix {
    inherit cppcoro nameof date;
    src = self.inputs.mirism-old;
    nghttp2 = pkgs.pkgs2305.nghttp2.override { enableAsioLib = true; };
  };
  cppcoro = pkgs.callPackage ./cppcoro { src = self.inputs.cppcoro; };
  date = pkgs.callPackage ./date.nix { src = self.inputs.date; };
  vasp = {
    gnu = pkgs.callPackage ./vasp/gnu {
      inherit (pkgs.llvmPackages) openmp;
      src = self.src.vasp.vasp;
      hdf5 = pkgs.hdf5.override {
        mpiSupport = true;
        fortranSupport = true;
        cppSupport = false;
      };
    };
    nvidia = pkgs.callPackage ./vasp/nvidia {
      inherit (nvhpcPackages) stdenv hdf5 mpi;
      src = self.src.vasp;
    };
    intel = pkgs.callPackage ./vasp/intel {
      src = self.src.vasp;
      inherit (pkgs.intelPackages_2023) stdenv;
      mpi = pkgs.openmpi.override {
        inherit (pkgs.intelPackages_2023) stdenv;
        enableSubstitute = false;
      };
      hdf5 = pkgs.hdf5.override {
        inherit (pkgs.intelPackages_2023) stdenv;
        cppSupport = false;
        fortranSupport = true;
      };
    };
    vtst = pkgs.callPackage ./vasp/vtst.nix { src = self.src.vasp.vtst.script; };
  };
  mumax = pkgs.callPackage ./mumax.nix { src = self.inputs.mumax; };
  biu = pkgs.callPackage ./biu {
    inherit
      nameof
      zpp-bits
      tgbot-cpp
      concurrencpp
      pocketfft
      ;
    # TODO: remove when boost 190 become default
    boost = pkgs.boost190;
    fmt = pkgs.fmt_11.overrideAttrs (prev: {
      patches = prev.patches or [ ] ++ [ ./biu/fmt.patch ];
    });
  };
  hpcstat = pkgs.callPackage ./hpcstat {
    inherit
      sqlite-orm
      date
      biu
      openxlsx
      ;
  };
  openxlsx = pkgs.callPackage ./openxlsx { src = self.inputs.openxlsx; };
  sqlite-orm = pkgs.callPackage ./sqlite-orm.nix { src = self.inputs.sqlite-orm; };
  mkPnpmPackage = pkgs.callPackage ./mkPnpmPackage.nix { };
  sbatch-tui = pkgs.callPackage ./sbatch-tui { inherit biu; };
  buildUfo = src: pkgs.callPackage src { inherit biu matplotplusplus; };
  ufo = buildUfo self.inputs.ufo;
  chn-bsub = pkgs.callPackage ./chn-bsub { inherit biu; };
  pocketfft = pkgs.callPackage ./pocketfft.nix { src = self.inputs.pocketfft; };
  vaspberry = pkgs.callPackage ./vaspberry.nix { src = self.inputs.vaspberry; };
  nvhpcPackages = pkgs.lib.makeScope pkgs.newScope (final: {
    stdenv = pkgs.callPackage ./nvhpc/stdenv.nix { src = self.src.nvhpc; };
    fmt = (pkgs.fmt.override { inherit (final) stdenv; }).overrideAttrs { doCheck = false; };
    hdf5 =
      (pkgs.hdf5-fortran.override {
        inherit (final) stdenv;
        cppSupport = false;
      }).overrideAttrs
        (prev: {
          patches = prev.patches or [ ] ++ [ ./nvhpc/hdf5.patch ];
          cmakeFlags = prev.cmakeFlags ++ [ "-DHDF5_ENABLE_NONSTANDARD_FEATURE_FLOAT16=OFF" ];
        });
    mpi = pkgs.callPackage ./nvhpc/mpi.nix {
      inherit (final) stdenv;
      src = self.src.nvhpc.mpi;
    };
  });
  gccFull = pkgs.symlinkJoin {
    name = "gcc";
    paths = with pkgs; [
      # wrapped binaries
      gcc
      gfortran
      glibc
      glibc.dev
      binutils
      iconv
      # not wrapped binaries
      gcc.cc
      gcc.cc.lib
      gfortran.cc
      gfortran.cc.lib
      binutils.bintools
    ];
  };
  stickerpicker = pkgs.python3Packages.callPackage ./stickerpicker.nix {
    src = self.inputs.stickerpicker;
  };
  info = pkgs.callPackage ./info { inherit biu; };
  blog = pkgs.callPackage self.inputs.blog {
    inherit (self.inputs) hextra;
    buildProxy = pkgs.mkBuildproxy ./blog-buildproxy.nix;
  };
  vm = pkgs.callPackage ./vm { inherit biu; };
  oneapiPackages = pkgs.lib.makeScope pkgs.newScope (final: {
    stdenv = pkgs.callPackage ./oneapi/stdenv.nix {
      src = self.src.oneapi;
      inherit gccFull;
    };
    fmt = (pkgs.fmt.override { inherit (final) stdenv; }).overrideAttrs {
      doCheck = false;
      env.VERBOSE = "1";
    };
  });
  lumerical = {
    lumerical = pkgs.callPackage ./lumerical/lumerical.nix { src = self.src.lumerical.lumerical; };
    licenseManager = pkgs.callPackage ./lumerical/licenseManager.nix {
      inherit (self.src.lumerical.licenseManager) src crack;
    };
    license = pkgs.callPackage ./lumerical/license.nix {
      src = self.src.lumerical.licenseManager.license;
    };
  };
  atat = pkgs.callPackage ./atat.nix { src = self.src.atat; };
  atomkit = pkgs.callPackage ./atomkit.nix { src = self.src.atomkit; };
  xinli = pkgs.callPackage ./xinli { inherit biu; };
  pybinding = pkgs.pkgs2411.python310Packages.callPackage ./pybinding {
    src = self.inputs.pybinding;
    buildProxy = pkgs.mkBuildproxy ./pybinding/proxy.nix;
  };
  missgram = pkgs.callPackage ./missgram { inherit biu sqlgen; };
  sqlgen = pkgs.callPackage ./sqlgen.nix {
    src = self.inputs.sqlgen;
    inherit reflectcpp;
  };
  reflectcpp = pkgs.callPackage ./reflectcpp.nix { src = self.inputs.reflectcpp; };
  lsf = pkgs.callPackage ./lsf.nix { src = self.src.lsf; };
  asmroner = pkgs.callPackage ./asmroner.nix { src = self.inputs.asmroner; };
  pythonOverlay = python3Packages: {
    py4vasp = python3Packages.callPackage ./py4vasp.nix { src = self.inputs.py4vasp; };
    phono3py = python3Packages.callPackage ./phono3py { src = self.src.phono3py; };
    brokenaxes = python3Packages.callPackage ./brokenaxes.nix { src = self.inputs.brokenaxes; };
    pyrho = python3Packages.callPackage ./pyrho.nix { src = self.src.pyrho; };
    pymatgen-analysis-defects = python3Packages.callPackage ./pymatgen-analysis-defects.nix {
      src = self.src.pymatgen-analysis-defects;
    };
    pydefect = python3Packages.callPackage ./pydefect.nix { src = self.inputs.pydefect; };
    matplotlib-label-lines = python3Packages.callPackage ./matplotlib-label-lines.nix {
      src = self.inputs.matplotlib-label-lines;
    };
    vise = python3Packages.callPackage ./vise.nix { src = self.inputs.vise; };
    mp-api = python3Packages.callPackage ./mp-api.nix { src = self.src.mp-api; };
    emmet-core = python3Packages.callPackage ./emmet-core.nix { src = self.src.emmet; };
    pymatgen-io-validation = python3Packages.callPackage ./pymatgen-io-validation.nix {
      src = self.src.pymatgen-io-validation;
    };
    pubchempy = python3Packages.callPackage ./pubchempy.nix { src = self.src.pubchempy; };
    shakenbreak = python3Packages.callPackage ./shakenbreak { src = self.src.shakenbreak; };
    cmcrameri = python3Packages.callPackage ./cmcrameri.nix { src = self.src.cmcrameri; };
    doped = python3Packages.callPackage ./doped.nix { src = self.src.doped; };
    hiphive = python3Packages.callPackage ./hiphive.nix { src = self.src.hiphive; };
    trainstation = python3Packages.callPackage ./trainstation.nix { src = self.src.trainstation; };
  };
  minibox = pkgs.callPackage ./minibox { };

  fromYaml =
    content:
    builtins.fromJSON (
      builtins.readFile (
        pkgs.runCommand "toJSON" { } "${pkgs.yj}/bin/yj < ${builtins.toFile "content.yaml" content} > $out"
      )
    );
  inherit (self.packages.x86_64-linux.dns-push.meta.config."chn.moe") getAddress;
}
