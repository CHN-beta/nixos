{ src, poetry2nix, runCommand }:
let
  package = poetry2nix.mkPoetryApplication { projectDir = src; };
  python = package.python.withPackages (p: [ package p.mdtraj ]);
in runCommand "py4vasp" {} "mkdir -p $out/bin; ln -s ${python}/bin/python $out/bin/py4vasp"
