inputs:
{
  config = inputs.lib.mkIf (builtins.elem "workstation" inputs.config.nixos.packages._packageSets)
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
          wl-mirror nvtopPackages.full
          # nix tools
          nix-template nil pnpm-lock-export bundix
          # instant messager
          cinny-desktop nheko # qq nur-xddxdd.wechat-uos 
          # development
          jetbrains.clion android-studio dbeaver-bin cling fprettify aircrack-ng
          # install per project
          # clang-tools_16 ccls 
          # media
          nur-xddxdd.svp
          # virtualization
          wineWowPackages.stagingFull virt-viewer bottles # wine64
          # text editor
          appflowy notion-app-enhanced joplin-desktop standardnotes logseq
          # math, physics and chemistry
          (mathematica.overrideAttrs (prev: { postInstall = prev.postInstall or "" + "ln -s ${src} $out/src"; }))
          (quantum-espresso.override { stdenv = gcc14Stdenv; gfortran = gfortran14; })
          jmol mpi
          # encryption and password management
          john crunch hashcat
          # container and vm
          genymotion davinci-resolve
          # TODO: broken on python 3.12
          # playonlinux
          # browser
          microsoft-edge
          # news
          rssguard newsflash newsboat
        ] ++ inputs.lib.optional (inputs.config.nixos.system.nixpkgs.march != null) localPackages.mumax;
        _pythonPackages = [(pythonPackages: with pythonPackages;
        [
          phonopy scipy scikit-learn jupyterlab autograd # localPackages.pix2tex
          # TODO: broken on python 3.12
          # tensorflow keras
        ])];
      };
      user.sharedModules =
      [{
        config.programs.obs-studio =
        {
          enable = true;
          plugins = with inputs.pkgs.obs-studio-plugins; [ wlrobs obs-vaapi obs-nvfbc droidcam-obs obs-vkcapture ];
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
