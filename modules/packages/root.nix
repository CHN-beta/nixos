{ lib, config, pkgs, ... }:
{
  options.nixos.packages.root = lib.mkOption
  {
    type = lib.types.nullOr (lib.types.submodule
    {
      options.jupyterKernelDefinition = lib.mkOption
      {
        type = lib.types.anything;
        readOnly = true;
        default = rec
        {
          displayName = "ROOT";
          language = "c++";
          argv = [ "/run/current-system/sw/bin/python3" "-m" "JupyROOT.kernel.rootkernel" "-f" "{connection_file}" ];
          logo64 = "${pkgs.root}/etc/notebook/kernels/root/logo-64x64.png";
          logo32 = pkgs.runCommand "logo-32x32.png" {} "${pkgs.imagemagick}/bin/convert ${logo64} -resize 32x32 $out";
        };
      };
    });
    default = if config.nixos.model.type == "desktop" then {} else null;
  };
  config = let inherit (config.nixos.packages) root; in lib.mkIf (root != null)
  {
    environment.systemPackages =  [ pkgs.root ];
    nixos.packages.packages =
      let jupyterKernel = pkgs.jupyter-kernel.create { definitions.root = root.jupyterKernelDefinition; }; in
      {
        _pythonPackages = [(pythonPackages: with pythonPackages; [ metakernel notebook ])];
        _pythonEnvFlags =
          [ "--prefix JUPYTER_PATH : ${jupyterKernel}" "--suffix NIX_PYTHONPATH : ${pkgs.root}/lib" ];
        _vscodeEnvFlags = [ "--prefix JUPYTER_PATH : ${jupyterKernel}" ];
      };
  };
}
