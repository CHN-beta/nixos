{ lib, config, pkgs, ... }:
{
  options.nixos.packages.root = lib.mkOption
  {
    type = lib.types.nullOr (lib.types.submodule {});
    default = if config.nixos.model.type == "desktop" then {} else null;
  };
  config = let inherit (config.nixos.packages) root; in lib.mkIf (root != null)
  {
    nixos.packages.packages =
      let
        inherit (pkgs) root;
        jupyterPath = pkgs.jupyter-kernel.create { definitions.root = rec
        {
          displayName = "ROOT";
          language = "c++";
          argv = [ "/run/current-system/sw/bin/python3" "-m" "JupyROOT.kernel.rootkernel" "-f" "{connection_file}" ];
          logo64 = "${root}/etc/notebook/kernels/root/logo-64x64.png";
          logo32 = pkgs.runCommand "logo-32x32.png" {} "${pkgs.imagemagick}/bin/convert ${logo64} -resize 32x32 $out";
        };};
      in
      {
        _packages = [ root ];
        _pythonPackages = [(pythonPackages: with pythonPackages; [ metakernel notebook ])];
        _pythonEnvFlags = [ "--prefix JUPYTER_PATH : ${jupyterPath}" "--suffix NIX_PYTHONPATH : ${root}/lib" ];
        _vscodeEnvFlags = [ "--prefix JUPYTER_PATH : ${jupyterPath}" ];
      };
  };
}
