{ lib, config, ... }:
{
  options.nixos.packages.desktopPython = lib.mkOption
    { type = lib.types.nullOr (lib.types.submodule {}); default = config.nixos.model.type == "desktop"; };
  config = let inherit (config.nixos.packages) desktopPython; in lib.mkIf (desktopPython != null)
  {
    nixos.packages.pythonPackages = [(pythonPackages: with pythonPackages;
    [
      scipy scikit-learn jupyterlab autograd phono3py numpy
      openai python-telegram-bot fastapi-cli pypdf2 pandas matplotlib plotly gunicorn redis jinja2 certifi 
      charset-normalizer idna orjson psycopg2 inquirerpy requests tqdm pydbus brokenaxes
      ipynbname
      # allow pandas read odf
      odfpy
    ])];
  };
}
