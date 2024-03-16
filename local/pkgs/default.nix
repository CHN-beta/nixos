inputs: rec
{
  typora = inputs.pkgs.callPackage ./typora {};
  vesta = inputs.pkgs.callPackage ./vesta {};
  rsshub = inputs.pkgs.callPackage ./rsshub { src = inputs.topInputs.rsshub; };
  misskey = inputs.pkgs.callPackage ./misskey { nodejs = inputs.pkgs.nodejs_21; src = inputs.topInputs.misskey; };
  mk-meili-mgn = inputs.pkgs.callPackage ./mk-meili-mgn {};
  vaspkit = inputs.pkgs.callPackage ./vaspkit { inherit (inputs.localLib) attrsToList; };
  v-sim = inputs.pkgs.callPackage ./v-sim { src = inputs.topInputs.v-sim; };
  concurrencpp = inputs.pkgs.callPackage ./concurrencpp
    { stdenv = inputs.pkgs.gcc13Stdenv; src = inputs.topInputs.concurrencpp; };
  eigengdb = inputs.pkgs.python3Packages.callPackage ./eigengdb {};
  nodesoup = inputs.pkgs.callPackage ./nodesoup { src = inputs.topInputs.nodesoup; };
  matplotplusplus = inputs.pkgs.callPackage ./matplotplusplus
    { inherit nodesoup glad; src = inputs.topInputs.matplotplusplus; };
  zpp-bits = inputs.pkgs.callPackage ./zpp-bits { src = inputs.topInputs.zpp-bits; };
  eigen = inputs.pkgs.callPackage ./eigen { src = inputs.topInputs.eigen; };
  nameof = inputs.pkgs.callPackage ./nameof { src = inputs.topInputs.nameof; };
  pslist = inputs.pkgs.callPackage ./pslist {};
  glad = inputs.pkgs.callPackage ./glad {};
  chromiumos-touch-keyboard = inputs.pkgs.callPackage ./chromiumos-touch-keyboard {};
  yoga-support = inputs.pkgs.callPackage ./yoga-support {};
  tgbot-cpp = inputs.pkgs.callPackage ./tgbot-cpp { src = inputs.topInputs.tgbot-cpp; };
  biu = inputs.pkgs.callPackage ./biu { inherit concurrencpp tgbot-cpp nameof; stdenv = inputs.pkgs.gcc13Stdenv; };
  citation-style-language = inputs.pkgs.callPackage ./citation-style-language
    { src = inputs.topInputs.citation-style-language; };
  mirism = inputs.pkgs.callPackage ./mirism
  {
    inherit cppcoro nameof tgbot-cpp date;
    nghttp2 = inputs.pkgs.callPackage "${inputs.topInputs."nixpkgs-23.05"}/pkgs/development/libraries/nghttp2"
      { enableAsioLib = true; };
  };
  cppcoro = inputs.pkgs.callPackage ./cppcoro { src = inputs.topInputs.cppcoro; };
  date = inputs.pkgs.callPackage ./date { src = inputs.topInputs.date; };
  esbonio = inputs.pkgs.python3Packages.callPackage ./esbonio {};
  pix2tex = inputs.pkgs.python3Packages.callPackage ./pix2tex {};
  pyreadline3 = inputs.pkgs.python3Packages.callPackage ./pyreadline3 {};
  torchdata = inputs.pkgs.python3Packages.callPackage ./torchdata {};
  torchtext = inputs.pkgs.python3Packages.callPackage ./torchtext { inherit torchdata; };
  win11os-kde = inputs.pkgs.callPackage ./win11os-kde { src = inputs.topInputs.win11os-kde; };
  fluent-kde = inputs.pkgs.callPackage ./fluent-kde { src = inputs.topInputs.fluent-kde; };
  blurred-wallpaper = inputs.pkgs.callPackage ./blurred-wallpaper { src = inputs.topInputs.blurred-wallpaper; };
  slate = inputs.pkgs.callPackage ./slate { src = inputs.topInputs.slate; };
  nvhpc = inputs.pkgs.callPackage ./nvhpc {};
  lmod = inputs.pkgs.callPackage ./lmod { src = inputs.topInputs.lmod; };
  vasp = rec
  {
    source = inputs.pkgs.callPackage ./vasp/source.nix {};
    gnu = inputs.pkgs.callPackage ./vasp/gnu
    {
      inherit (inputs.pkgs.llvmPackages) openmp;
      inherit wannier90 additionalCommands;
      hdf5 = inputs.pkgs.hdf5.override { mpiSupport = true; fortranSupport = true; };
    };
    nvidia = inputs.pkgs.callPackage ./vasp/nvidia
      { inherit lmod nvhpc wannier90 additionalCommands; hdf5 = hdf5-nvhpc; };
    intel = inputs.pkgs.callPackage ./vasp/intel
      { inherit lmod oneapi wannier90 additionalCommands; hdf5 = hdf5-oneapi; };
    amd = inputs.pkgs.callPackage ./vasp/amd
      { inherit aocc aocl wannier90 additionalCommands; hdf5 = hdf5-aocc; openmpi = openmpi-aocc; gcc = gcc-pie; };
    wannier90 = inputs.pkgs.callPackage
      "${inputs.topInputs.nixpkgs-unstable}/pkgs/by-name/wa/wannier90/package.nix" {};
    hdf5-nvhpc = inputs.pkgs.callPackage ./vasp/hdf5-nvhpc { inherit lmod nvhpc; inherit (inputs.pkgs.hdf5) src; };
    hdf5-oneapi = inputs.pkgs.callPackage ./vasp/hdf5-oneapi { inherit lmod oneapi; inherit (inputs.pkgs.hdf5) src; };
    hdf5-aocc = inputs.pkgs.callPackage ./vasp/hdf5-aocc
      { inherit (inputs.pkgs.hdf5) src; inherit aocc; openmpi = openmpi-aocc; gcc = gcc-pie; };
    openmpi-aocc = inputs.pkgs.callPackage ./vasp/openmpi-aocc { inherit aocc; gcc = gcc-pie; };
    gcc-pie = inputs.pkgs.wrapCC (inputs.pkgs.gcc.cc.overrideAttrs (prev:
      { configureFlags = prev.configureFlags ++ [ "--enable-default-pie" ];}));
    additionalCommands =
      ''[ "$(id -u)" -eq ${builtins.toString inputs.config.nixos.system.user.user.gb} ] && exit 1'';
  };
  oneapi = inputs.pkgs.callPackage ./oneapi {};
  mumax = inputs.pkgs.callPackage ./mumax { src = inputs.topInputs.mumax; };
  aocc = inputs.pkgs.callPackage ./aocc {};
  aocl = inputs.pkgs.callPackage ./aocl {};
}
