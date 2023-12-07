inputs:
{
  config =
    let
      inherit (inputs.lib) mkIf;
    in mkIf (builtins.elem "workstation" inputs.config.nixos.packages._packageSets)
    {
      nixos.packages = with inputs.pkgs;
      {
        _packages =
        [
          # nix tools
          nix-template appimage-run nil nixd nix-alien nix-serve node2nix nix-prefetch-github prefetch-npm-deps
          nix-prefetch-docker pnpm-lock-export bundix
          # instant messager
          zoom-us signal-desktop qq nur-xddxdd.wechat-uos slack # jail
          # office
          libreoffice-qt texstudio poppler_utils pdftk gnuplot pdfchain
          (texlive.combine { inherit (texlive) scheme-full; inherit (localPackages) citation-style-language; })
          # development
          jetbrains.clion android-studio dbeaver cling clang-tools_16 ccls fprettify aircrack-ng
          # media
          nur-xddxdd.svp obs-studio waifu2x-converter-cpp inkscape blender
          # virtualization
          wineWowPackages.stagingFull virt-viewer bottles # wine64
          # text editor
          appflowy notion-app-enhanced joplin-desktop standardnotes
          # math, physics and chemistry
          mathematica octaveFull root ovito paraview localPackages.vesta qchem.quantum-espresso
          localPackages.vasp localPackages.vaspkit jmol localPackages.v_sim
          # encryption and password management
          john crunch hashcat
          # container and vm
          genymotion # davinci-resolve playonlinux
        ];
        _pythonPackages = [(pythonPackages: with pythonPackages;
        [
          phonopy tensorflow keras openai scipy scikit-learn jupyterlab autograd
          # localPackages.pix2tex
        ])];
        _prebuildPackages =
        [
          httplib magic-enum xtensor boost cereal cxxopts ftxui yaml-cpp gfortran gcc10 python2
          gcc13Stdenv
        ];
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
