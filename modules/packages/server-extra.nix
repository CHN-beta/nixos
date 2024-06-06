inputs:
{
  config = inputs.lib.mkIf (builtins.elem "server-extra" inputs.config.nixos.packages._packageSets)
  {
    nixos =
    {
      packages = with inputs.pkgs;
      {
        _packages =
        [
          # shell
          ksh
          # basic tools
          neofetch
          # office
          todo-txt-cli pdfgrep ffmpeg-full
          # development
          hexo-cli gh nix-init
        ]
        ++ (with inputs.config.boot.kernelPackages; [ cpupower usbip ])
        ++ (inputs.lib.optional (inputs.config.nixos.system.nixpkgs.arch == "x86_64") rar);
        _pythonPackages = [(pythonPackages: with pythonPackages;
        [
          openai python-telegram-bot fastapi pypdf2 pandas matplotlib plotly gunicorn redis jinja2
          certifi charset-normalizer idna orjson psycopg2 inquirerpy requests tqdm pydbus
        ])];
      };
    };
    programs =
    {
      yazi.enable = true;
      mosh.enable = true;
    };
    services.fwupd.enable = true;
  };
}
