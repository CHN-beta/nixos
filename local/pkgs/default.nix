inputs: rec
{
  typora = inputs.pkgs.callPackage ./typora {};
  vesta = inputs.pkgs.callPackage ./vesta {};
  rsshub = inputs.pkgs.callPackage ./rsshub.nix { inherit mkPnpmPackage; src = inputs.topInputs.rsshub; };
  misskey = inputs.pkgs.callPackage ./misskey.nix
    { inherit mkPnpmPackage; src = inputs.topInputs.misskey; nodejs = nodejs-with-pnpm9; };
  mk-meili-mgn = inputs.pkgs.callPackage ./mk-meili-mgn {};
  vaspkit = inputs.pkgs.callPackage ./vaspkit { inherit (inputs.localLib) attrsToList; };
  v-sim = inputs.pkgs.callPackage ./v-sim { src = inputs.topInputs.v-sim; };
  concurrencpp = inputs.pkgs.callPackage ./concurrencpp { src = inputs.topInputs.concurrencpp; };
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
  mirism = inputs.pkgs.callPackage ./mirism
  {
    inherit cppcoro nameof tgbot-cpp date;
    nghttp2 = inputs.pkgs.callPackage "${inputs.topInputs."nixpkgs-23.05"}/pkgs/development/libraries/nghttp2"
      { enableAsioLib = true; stdenv = inputs.pkgs.gcc12Stdenv; };
    stdenv = inputs.pkgs.gcc12Stdenv;
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
    src = inputs.pkgs.callPackage ./vasp/source.nix {};
    gnu = inputs.pkgs.callPackage ./vasp/gnu
    {
      inherit (inputs.pkgs.llvmPackages) openmp;
      inherit wannier90 src;
      hdf5 = inputs.pkgs.hdf5.override { mpiSupport = true; fortranSupport = true; cppSupport = false; };
    };
    nvidia = inputs.pkgs.callPackage ./vasp/nvidia
      { inherit lmod nvhpc wannier90 vtst src; hdf5 = hdf5-nvhpc; };
    intel = inputs.pkgs.callPackage ./vasp/intel
      { inherit lmod oneapi wannier90 vtst src; hdf5 = hdf5-oneapi; };
    wannier90 = inputs.pkgs.callPackage
      "${inputs.topInputs.nixpkgs-unstable}/pkgs/by-name/wa/wannier90/package.nix" {};
    hdf5-nvhpc = inputs.pkgs.callPackage ./vasp/hdf5-nvhpc { inherit lmod nvhpc; inherit (inputs.pkgs.hdf5) src; };
    hdf5-oneapi = inputs.pkgs.callPackage ./vasp/hdf5-oneapi { inherit lmod oneapi; inherit (inputs.pkgs.hdf5) src; };
    vtst = (inputs.pkgs.callPackage ./vasp/vtst.nix {});
    vtstscripts = inputs.pkgs.callPackage ./vasp/vtstscripts.nix {};
  };
  # TODO: use other people packaged hpc version
  oneapi = inputs.pkgs.callPackage ./oneapi {};
  mumax = inputs.pkgs.callPackage ./mumax { src = inputs.topInputs.mumax; };
  kylin-virtual-keyboard = inputs.pkgs.libsForQt5.callPackage ./kylin-virtual-keyboard
    { src = inputs.topInputs.kylin-virtual-keyboard; };
  biu = inputs.pkgs.callPackage ./biu { inherit nameof; };
  zxorm = inputs.pkgs.callPackage ./zxorm { src = inputs.topInputs.zxorm; };
  hpcstat = inputs.pkgs.callPackage ./hpcstat { inherit nameof sqlite-orm zpp-bits date openxlsx; };
  openxlsx = inputs.pkgs.callPackage ./openxlsx { src = inputs.topInputs.openxlsx; };
  sqlite-orm = inputs.pkgs.callPackage ./sqlite-orm { src = inputs.topInputs.sqlite-orm; };
  mkPnpmPackage = inputs.pkgs.callPackage ./mkPnpmPackage.nix {};
  nodejs-with-pnpm9 = inputs.pkgs.callPackage ./nodejs-with-pnpm9.nix {};

  fromYaml = content: builtins.fromJSON (builtins.readFile
    (inputs.pkgs.runCommand "toJSON" {}
      "${inputs.pkgs.remarshal}/bin/yaml2json ${builtins.toFile "content.yaml" content} $out"));
}
