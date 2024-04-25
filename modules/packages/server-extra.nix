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
          # nix tools
          inputs.topInputs.nix-inspect.packages."${inputs.config.nixos.system.nixpkgs.arch}-linux".default
          # office
          todo-txt-cli pdfgrep
          # development
          hexo-cli gh
          # install per project
          # stdenv gfortran nodejs
          # library
          # fmt fmt.dev localPackages.nameof localPackages.matplotplusplus highfive hdf5 hdf5.dev
          # localPackages.concurrencpp localPackages.biu localPackages.magik-enum
          # (
          #   runCommand "concurrencpp" {}
          #     "mkdir $out; ln -s ${localPackages.concurrencpp}/include/concurrencpp-* $out/include"
          # )
          # eigen (runCommand "eigen" {} "mkdir $out; ln -s ${eigen}/include/eigen3 $out/include")
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
