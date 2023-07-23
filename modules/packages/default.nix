inputs:
{
  options.nixos.packages = let inherit (inputs.lib) mkOption types; in
  {
    packages = mkOption { default = []; type = types.listOf (types.enum
    [
      "games" "wine" "gui-extra" "office" "vscode"
    ]); };
  };
  config = let inherit (inputs.lib) mkMerge mkIf; in mkMerge
  [
    (
      mkIf (builtins.elem "games" inputs.config.nixos.packages.packages) { programs =
      {
        anime-game-launcher.enable = true;
        honkers-railway-launcher.enable = true;
        steam.enable = true;
      };}
    )
    (
      mkIf (builtins.elem "wine" inputs.config.nixos.packages.packages)
        { environment.systemPackages = [ inputs.pkgs.wine ]; }
    )
    (
      mkIf (builtins.elem "gui-extra" inputs.config.nixos.packages.packages)
        { environment.systemPackages = with inputs.pkgs; [ qbittorrent element-desktop tdesktop discord ]; }
    )
    (
      mkIf (builtins.elem "office" inputs.config.nixos.packages.packages)
        { environment.systemPackages = with inputs.pkgs; [ libreoffice-qt ]; }
    )
    (
      mkIf (builtins.elem "vscode" inputs.config.nixos.packages.packages)
        { environment.systemPackages = [(inputs.pkgs.vscode-with-extensions.override
          {
            vscodeExtensions = (with inputs.pkgs.vscode-extensions;
            [
              ms-vscode.cpptools
              genieai.chatgpt-vscode
              ms-ceintl.vscode-language-pack-zh-hans
              llvm-vs-code-extensions.vscode-clangd
              twxs.cmake
              ms-vscode.cmake-tools
              donjayamanne.githistory
              github.copilot
              github.github-vscode-theme
              ms-vscode.hexeditor
              oderwat.indent-rainbow
              ms-toolsai.jupyter
              ms-toolsai.vscode-jupyter-cell-tags
              ms-toolsai.jupyter-keymap
              ms-toolsai.jupyter-renderers
              ms-toolsai.vscode-jupyter-slideshow
              james-yu.latex-workshop
              yzhang.markdown-all-in-one
              pkief.material-icon-theme
              equinusocio.vsc-material-theme
              bbenoist.nix
              ms-python.vscode-pylance
              ms-python.python
              ms-vscode-remote.remote-ssh
              redhat.vscode-xml
              dotjoshjohnson.xml
              jnoortheen.nix-ide
            ])
            ++ (with inputs.pkgs.nix-vscode-extensions.vscode-marketplace;
            [
              jeff-hykin.better-cpp-syntax
              ms-vscode.cpptools-extension-pack
              ms-vscode.cpptools-themes
              josetr.cmake-language-support-vscode
              fredericbonnet.cmake-test-adapter
              equinusocio.vsc-community-material-theme
              guyutongxue.cpp-reference
              intellsmi.comment-translate
              intellsmi.deepl-translate
              ms-vscode-remote.remote-containers
              fabiospampinato.vscode-diff
              cschlosser.doxdocgen
              znck.grammarly
              ms-python.isort
              thfriedrich.lammps
              leetcode.vscode-leetcode
              equinusocio.vsc-material-theme-icons
              gimly81.matlab
              affenwiesel.matlab-formatter
              xdebug.php-debug
              ckolkman.vscode-postgres
              ms-ossdata.vscode-postgresql
              ms-vscode-remote.remote-ssh-edit
              ms-vscode.remote-explorer
              ms-vscode.test-adapter-converter
              hbenl.vscode-test-explorer
              hirse.vscode-ungit
              fortran-lang.linter-gfortran
            ]);
          }
        ) ]; }
    )
  ];
}
