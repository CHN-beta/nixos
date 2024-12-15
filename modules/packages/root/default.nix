inputs:
{
  options.nixos.packages.root = let inherit (inputs.lib) mkOption types; in mkOption
    { type = types.nullOr (types.submodule {}); default = {}; };
  config = let inherit (inputs.config.nixos.packages) root; in inputs.lib.mkIf (root != null)
  {
    nixos.packages.packages =
      let
        root = inputs.pkgs.root.overrideAttrs (prev:
        {
          patches = prev.patches or [] ++ [ ./17253.patch ./17273.patch ];
          cmakeFlags = prev.cmakeFlags ++ [ "-DCMAKE_CXX_STANDARD=23" ];
        });
        jupyterPath = inputs.pkgs.jupyter-kernel.create { definitions.root = rec
        {
          displayName = "ROOT";
          language = "c++";
          argv = [ "/run/current-system/sw/bin/python3" "-m" "JupyROOT.kernel.rootkernel" "-f" "{connection_file}" ];
          logo64 = "${root}/etc/root/notebook/kernels/root/logo-64x64.png";
          logo32 = inputs.pkgs.runCommand "logo-32x32.png" {}
            "${inputs.pkgs.imagemagick}/bin/convert ${logo64} -resize 32x32 $out";
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
