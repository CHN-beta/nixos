{ lib, pkgs }: with pkgs; rec
{
  typora = callPackage ./typora {};
  vesta = callPackage ./vesta {};
  oneapi = callPackage ./oneapi {};
  rsshub = callPackage ./rsshub {};
  misskey = callPackage ./misskey {};
  mk-meili-mgn = callPackage ./mk-meili-mgn {};
  # vasp = callPackage ./vasp
  # {
  #   stdenv = pkgs.lmix-pkgs.intel21Stdenv;
  #   intel-mpi = pkgs.lmix-pkgs.intel-oneapi-mpi_2021_9_0;
  #   ifort = pkgs.lmix-pkgs.intel-oneapi-ifort_2021_9_0;
  # };
  vasp = callPackage ./vasp
  {
    openmp = llvmPackages.openmp;
    openmpi = pkgs.openmpi.override { cudaSupport = false; };
  };
  vaspkit = callPackage ./vaspkit { attrsToList = (import ../lib lib).attrsToList; };
  v_sim = callPackage ./v_sim {};
  concurrencpp = callPackage ./concurrencpp { stdenv = gcc13Stdenv; };
  eigengdb = python3Packages.callPackage ./eigengdb {};
  nodesoup = callPackage ./nodesoup {};
  matplotplusplus = callPackage ./matplotplusplus { inherit nodesoup glad; };
  zpp-bits = callPackage ./zpp-bits {};
  eigen = callPackage ./eigen {};
  nameof = callPackage ./nameof {};
  pslist = callPackage ./pslist {};
  glad = callPackage ./glad {};
  chromiumos-touch-keyboard = callPackage ./chromiumos-touch-keyboard {};
  yoga-support = callPackage ./yoga-support {};
  tgbot-cpp = callPackage ./tgbot-cpp {};
  biu = callPackage ./biu { inherit concurrencpp tgbot-cpp nameof; stdenv = gcc13Stdenv; };
  citation-style-language = callPackage ./citation-style-language {};
  mirism = callPackage ./mirism
  {
    inherit cppcoro nameof tgbot-cpp date;
    nghttp2 = nghttp2-2305.override { enableAsioLib = true; };
  };
  cppcoro = callPackage ./cppcoro {};
  date = callPackage ./date {};
  esbonio = python3Packages.callPackage ./esbonio {};
  pix2tex = python3Packages.callPackage ./pix2tex {};
  pyreadline3 = python3Packages.callPackage ./pyreadline3 {};
  torchdata = python3Packages.callPackage ./torchdata {};
  torchtext = python3Packages.callPackage ./torchtext { inherit torchdata; };
}
