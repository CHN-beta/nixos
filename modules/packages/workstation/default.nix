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
            wl-mirror nvtop
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
            mathematica paraview jmol
            # qchem.quantum-espresso
            # encryption and password management
            john crunch hashcat
            # container and vm
            genymotion # davinci-resolve playonlinux
            # browser
            microsoft-edge
            # news
            rssguard newsflash newsboat
            yuzu-early-access
          ] ++ (with localPackages; [ vasp."6.3.1" vasp."6.4.0" vasp-gpu."6.4.0" vasp-gpu."6.3.1" ]);
          _pythonPackages = [(pythonPackages: with pythonPackages;
          [
            phonopy tensorflow keras scipy scikit-learn jupyterlab autograd # localPackages.pix2tex
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
      };
    };
}
