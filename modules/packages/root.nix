inputs:
{
  options.nixos.packages.root = let inherit (inputs.lib) mkOption types; in mkOption
    { type = types.nullOr (types.submodule {}); default = {}; };
  config = let inherit (inputs.config.nixos.packages) root; in inputs.lib.mkIf (root != null)
  {
    nixos.packages.packages =
      let
        root = inputs.pkgs.root.overrideAttrs rec
        {
          version = "6.34.00-rc1";
          src = inputs.pkgs.fetchurl
          {
            url = "https://root.cern/download/root_v${version}.source.tar.gz";
            sha256 = "1fx6nyv3drcb16a36np7h3vmjlm937j6y9vxkv0sny0grrxcj9lw";
          };
          patches = [];
        };
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
        _pythonEnvFlags =
        [
          "--prefix JUPYTER_PATH : ${jupyterPath}"
          "--suffix NIX_PYTHONPATH : ${root}/lib"
        ];
        _vscodeEnvFlags = [ "--prefix JUPYTER_PATH : ${jupyterPath}" ];
      };
  };
}
