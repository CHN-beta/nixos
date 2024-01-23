inputs:
{
  config =
    let
      inherit (inputs.lib) mkIf;
    in mkIf (builtins.elem "workstation" inputs.config.nixos.packages._packageSets)
    {
      nixos =
      {
        packages = with inputs.pkgs;
        {
          _packages =
          [
            # password and key management
            electrum jabref
            # system management
            wl-mirror
            # nix tools
            nix-template nil nix-alien pnpm-lock-export bundix
            # instant messager
            qq nur-xddxdd.wechat-uos cinny-desktop nheko
            # development
            jetbrains.clion android-studio dbeaver cling clang-tools_16 ccls fprettify aircrack-ng
            # media
            nur-xddxdd.svp
            # virtualization
            wineWowPackages.stagingFull virt-viewer bottles # wine64
            # text editor
            appflowy notion-app-enhanced joplin-desktop standardnotes logseq
            # math, physics and chemistry
            mathematica paraview localPackages.vasp jmol # qchem.quantum-espresso
            # encryption and password management
            john crunch hashcat
            # container and vm
            genymotion # davinci-resolve playonlinux
            # browser
            microsoft-edge
            # news
            rssguard newsflash newsboat
          ];
          _pythonPackages = [(pythonPackages: with pythonPackages;
          [
            phonopy tensorflow keras openai scipy scikit-learn jupyterlab autograd
            # localPackages.pix2tex
            inquirerpy requests python-telegram-bot tqdm fastapi pypdf2 pandas matplotlib plotly gunicorn redis jinja2
            certifi charset-normalizer idna orjson psycopg2
          ])];
          _prebuildPackages =
          [
            httplib magic-enum xtensor boost cereal cxxopts ftxui yaml-cpp gfortran gcc10 python2
            gcc13Stdenv
          ];
        };
        users.sharedModules =
        [{
          config.programs =
          {
            obs-studio =
            {
              enable = true;
              plugins = with inputs.pkgs.obs-studio-plugins;
                [ wlrobs obs-vaapi obs-nvfbc droidcam-obs obs-vkcapture ];
            };
            doom-emacs = { enable = true; doomPrivateDir = ./doom.d; };
          };
        }];
      };
      programs =
      {
        anime-game-launcher = { enable = true; package = inputs.pkgs.anime-game-launcher; };
        honkers-railway-launcher = { enable = true; package = inputs.pkgs.honkers-railway-launcher; };
        nix-ld.enable = true;
        gamemode =
        {
          enable = true;
          settings =
          {
            general.renice = 10;
            gpu =
            {
              apply_gpu_optimisations = "accept-responsibility";
              nv_powermizer_mode = 1;
            };
            custom = let notify-send = "${inputs.pkgs.libnotify}/bin/notify-send"; in
            {
              start = "${notify-send} 'GameMode started'";
              end = "${notify-send} 'GameMode ended'";
            };
          };
        };
        chromium =
        {
          enable = true;
          extraOpts.PasswordManagerEnabled = false;
        };
      };
    };
}
