inputs:
{
  config =
    let
      inherit (inputs.lib) mkIf;
    in mkIf (builtins.elem "desktop" inputs.config.nixos.packages._packageSets)
    {
      nixos.packages = with inputs.pkgs;
      {
        _packages =
        [(
          vscode-with-extensions.override
          {
            vscodeExtensions = with nix-vscode-extensions.vscode-marketplace;
              (with equinusocio; [ vsc-community-material-theme vsc-material-theme-icons ])
              ++ (with github; [ copilot copilot-chat github-vscode-theme ])
              ++ (with intellsmi; [ comment-translate deepl-translate ])
              ++ (with ms-python; [ isort python vscode-pylance ])
              ++ (with ms-toolsai;
              [
                jupyter jupyter-keymap jupyter-renderers vscode-jupyter-cell-tags vscode-jupyter-slideshow
              ])
              ++ (with ms-vscode;
              [
                (cmake-tools.overrideAttrs { sourceRoot = "extension"; }) cpptools cpptools-extension-pack cpptools-themes hexeditor remote-explorer
                test-adapter-converter
              ])
              ++ (with ms-vscode-remote; [ remote-ssh remote-containers remote-ssh-edit ])
              ++ [
                donjayamanne.githistory genieai.chatgpt-vscode fabiospampinato.vscode-diff cschlosser.doxdocgen
                llvm-vs-code-extensions.vscode-clangd ms-ceintl.vscode-language-pack-zh-hans
                oderwat.indent-rainbow
                twxs.cmake guyutongxue.cpp-reference znck.grammarly thfriedrich.lammps leetcode.vscode-leetcode
                james-yu.latex-workshop gimly81.matlab affenwiesel.matlab-formatter ckolkman.vscode-postgres
                yzhang.markdown-all-in-one pkief.material-icon-theme bbenoist.nix ms-ossdata.vscode-postgresql
                redhat.vscode-xml dotjoshjohnson.xml jnoortheen.nix-ide xdebug.php-debug
                hbenl.vscode-test-explorer
                jeff-hykin.better-cpp-syntax fredericbonnet.cmake-test-adapter mesonbuild.mesonbuild
                hirse.vscode-ungit fortran-lang.linter-gfortran tboox.xmake-vscode ccls-project.ccls
                feiskyer.chatgpt-copilot yukiuuh2936.vscode-modern-fortran-formatter wolframresearch.wolfram
                njpipeorgan.wolfram-language-notebook brettm12345.nixfmt-vscode webfreak.debug
                gruntfuggly.todo-tree
                # restrctured text
                lextudio.restructuredtext trond-snekvik.simple-rst
                # markdown
                shd101wyy.markdown-preview-enhanced
                # vasp
                mystery.vasp-support
                yutengjing.open-in-external-app
                # ChatGPT-like plugin
                codeium.codeium
              ];
          }
        )];
        _pythonPackages = [(pythonPackages: with pythonPackages;
        [
          # required by vscode extensions restrucuredtext
          localPackages.esbonio
        ])];
      };
    };
}
