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
            nix-template nil pnpm-lock-export bundix
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
            mathematica paraview jmol mpi quantum-espresso # localPackages.mumax
            # encryption and password management
            john crunch hashcat
            # container and vm
            genymotion davinci-resolve playonlinux
            # browser
            microsoft-edge tor-browser
            # news
            rssguard newsflash newsboat
          ];
          _pythonPackages = [(pythonPackages: with pythonPackages;
          [
            phonopy tensorflow keras scipy scikit-learn jupyterlab autograd # localPackages.pix2tex
          ])];
        };
        user.sharedModules =
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
      };
    };
}
