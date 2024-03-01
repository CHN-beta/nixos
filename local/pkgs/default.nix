{ lib, pkgs, topInputs }: with pkgs; rec
{
  typora = callPackage ./typora {};
  vesta = callPackage ./vesta {};
  rsshub = callPackage ./rsshub { src = topInputs.rsshub; };
  misskey = callPackage ./misskey { nodejs = nodejs_21; src = topInputs.misskey; };
  mk-meili-mgn = callPackage ./mk-meili-mgn {};
  vaspkit = callPackage ./vaspkit { attrsToList = (import ../lib lib).attrsToList; };
  v-sim = callPackage ./v-sim { src = topInputs.v-sim; };
  concurrencpp = callPackage ./concurrencpp { stdenv = gcc13Stdenv; src = topInputs.concurrencpp; };
  eigengdb = python3Packages.callPackage ./eigengdb {};
  nodesoup = callPackage ./nodesoup { src = topInputs.nodesoup; };
  matplotplusplus = callPackage ./matplotplusplus { inherit nodesoup glad; src = topInputs.matplotplusplus; };
  zpp-bits = callPackage ./zpp-bits { src = topInputs.zpp-bits; };
  eigen = callPackage ./eigen { src = topInputs.eigen; };
  nameof = callPackage ./nameof { src = topInputs.nameof; };
  pslist = callPackage ./pslist {};
  glad = callPackage ./glad {};
  chromiumos-touch-keyboard = callPackage ./chromiumos-touch-keyboard {};
  yoga-support = callPackage ./yoga-support {};
  tgbot-cpp = callPackage ./tgbot-cpp { src = topInputs.tgbot-cpp; };
  biu = callPackage ./biu { inherit concurrencpp tgbot-cpp nameof; stdenv = gcc13Stdenv; };
  citation-style-language = callPackage ./citation-style-language { src = topInputs.citation-style-language; };
  mirism = callPackage ./mirism
  {
    inherit cppcoro nameof tgbot-cpp date;
    nghttp2 = nghttp2-2305.override { enableAsioLib = true; };
  };
  cppcoro = callPackage ./cppcoro { src = topInputs.cppcoro; };
  date = callPackage ./date { src = topInputs.date; };
  esbonio = python3Packages.callPackage ./esbonio {};
  pix2tex = python3Packages.callPackage ./pix2tex {};
  pyreadline3 = python3Packages.callPackage ./pyreadline3 {};
  torchdata = python3Packages.callPackage ./torchdata {};
  torchtext = python3Packages.callPackage ./torchtext { inherit torchdata; };
  win11os-kde = callPackage ./win11os-kde { src = topInputs.win11os-kde; };
  fluent-kde = callPackage ./fluent-kde { src = topInputs.fluent-kde; };
  blurred-wallpaper = callPackage ./blurred-wallpaper { src = topInputs.blurred-wallpaper; };
  slate = callPackage ./slate { src = topInputs.slate; };
  nvhpc = callPackage ./nvhpc {};
  lmod = callPackage ./lmod { src = topInputs.lmod; };
  vasp =
  {
    source = callPackage ./vasp/source.nix {};
    gnu = callPackage ./vasp/gnu
    {
      inherit (llvmPackages) openmp;
      inherit (unstablePackages) wannier90;
      hdf5 = hdf5.override { mpiSupport = true; fortranSupport = true; };
    };
    nvidia = callPackage ./vasp/nvidia
    {
      inherit lmod;
      nvhpc = nvhpc."24.1";
      hdf5 = hdf5-nvhpc.override { nvhpc = nvhpc."24.1"; };
      inherit (unstablePackages) wannier90;
    };
    intel = callPackage ./vasp/intel
    {
      inherit lmod;
      oneapi = oneapi."2022.2";
      hdf5 = hdf5.override { mpiSupport = true; fortranSupport = true; };
      inherit (unstablePackages) wannier90;
    };
  };
  hdf5-nvhpc = callPackage ./hdf5-nvhpc { inherit lmod; inherit (hdf5) src; nvhpc = nvhpc."24.1"; };
  oneapi = callPackage ./oneapi {};
  mumax = callPackage ./mumax { src = topInputs.mumax; };
}
