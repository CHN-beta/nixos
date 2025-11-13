inputs:
{
  options.nixos.packages.server = let inherit (inputs.lib) mkOption types; in mkOption
  {
    type = types.nullOr (types.submodule {});
    default = if builtins.elem inputs.config.nixos.model.type [ "server" "desktop" ] then {} else null;
  };
  config = let inherit (inputs.config.nixos.packages) server; in inputs.lib.mkIf (server != null)
  {
    nixos.packages.packages =
    {
      _packages = with inputs.pkgs;
      [
        # office
        pdfgrep ffmpeg-full hdf5
        # scientific computing
        (if inputs.config.nixos.system.nixpkgs.cuda != null then localPackages.mumax else emptyDirectory)
        (if inputs.config.nixos.system.nixpkgs.cuda != null
          then (lammps.override { stdenv = cudaPackages.backendStdenv; }).overrideAttrs (prev:
          {
            cmakeFlags = prev.cmakeFlags ++
              [ "-DPKG_GPU=on" "-DGPU_API=cuda" "-DCMAKE_POLICY_DEFAULT_CMP0146=OLD" ];
            nativeBuildInputs = prev.nativeBuildInputs ++ [ cudaPackages.cudatoolkit ];
            buildInputs = prev.buildInputs ++ [ mpi ];
          })
          else lammps-mpi)
      ];
      _pythonPackages = [(pythonPackages: with pythonPackages;
      [
        openai python-telegram-bot fastapi-cli pypdf2 pandas matplotlib plotly gunicorn redis jinja2 certifi 
        charset-normalizer idna orjson psycopg2 inquirerpy requests tqdm pydbus inputs.pkgs.localPackages.brokenaxes
        # allow pandas read odf
        odfpy
        # for vasp plot-workfunc.py
        ase
      ])];
    };
  };
}
