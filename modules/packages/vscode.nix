inputs:
{
  options.nixos.packages.vscode = let inherit (inputs.lib) mkOption types; in mkOption
  {
    type = types.nullOr (types.submodule {});
    default = if inputs.config.nixos.model.type == "desktop" then {} else null;
  };
  config = let inherit (inputs.config.nixos.packages) vscode; in inputs.lib.mkIf (vscode != null)
  {
    nixos.packages.packages = with inputs.pkgs;
    {
      _packages =
      [(
        vscode-with-extensions.override
        {
          vscodeExtensions =
            let extensions = builtins.listToAttrs (builtins.map
              (set:
              {
                name = set;
                value =
                  # provided by nixpkgs
                  vscode-extensions.${set} or {}
                  # provided by nix-vscode-extensions, including pre-release versions, but prefer stable version
                  // nix-vscode-extensions.vscode-marketplace.${set} or {}
                  // nix-vscode-extensions.vscode-marketplace-release.${set} or {}
                  # some versions are too high for the current vscode, use old version from here to override it
                  // (nix-vscode-extensions.forVSCodeVersion inputs.pkgs.vscode.version)
                    .vscode-marketplace-release.${set} or {};
              })
              (inputs.lib.unique
              (
                (builtins.attrNames vscode-extensions)
                  ++ (builtins.attrNames nix-vscode-extensions.vscode-marketplace)
                  ++ (builtins.attrNames nix-vscode-extensions.vscode-marketplace-release)
              )));
            in with extensions;
              (with github; [ copilot copilot-chat github-vscode-theme ])
              ++ (with intellsmi; [ comment-translate ])
              ++ (with ms-vscode; [ cmake-tools cpptools-extension-pack hexeditor remote-explorer ])
              ++ (with ms-vscode-remote; [ remote-ssh ])
              ++ [
                donjayamanne.githistory fabiospampinato.vscode-diff
                llvm-vs-code-extensions.vscode-clangd ms-ceintl.vscode-language-pack-zh-hans
                oderwat.indent-rainbow
                twxs.cmake guyutongxue.cpp-reference thfriedrich.lammps leetcode.vscode-leetcode # znck.grammarly
                james-yu.latex-workshop bbenoist.nix jnoortheen.nix-ide ccls-project.ccls
                brettm12345.nixfmt-vscode
                gruntfuggly.todo-tree
                # restrctured text
                lextudio.restructuredtext trond-snekvik.simple-rst swyddfa.esbonio chrisjsewell.myst-tml-syntax
                # markdown
                yzhang.markdown-all-in-one shd101wyy.markdown-preview-enhanced
                # vasp
                mystery.vasp-support
                yutengjing.open-in-external-app
                # git graph
                mhutchie.git-graph
                # python
                ms-python.python
                # theme
                pkief.material-icon-theme
                # direnv
                mkhl.direnv
                # svg viewer
                vitaliymaz.vscode-svg-previewer
                # draw
                pomdtr.excalidraw-editor
                # typst
                myriad-dreamin.tinymist
                # grammaly alternative
                ltex-plus.vscode-ltex-plus
              ]
              # jupyter
              # TODO: pick all extensions from nixpkgs or nix-vscode-extensions, explicitly
              ++ (with vscode-extensions.ms-toolsai;
              [
                jupyter jupyter-keymap jupyter-renderers vscode-jupyter-cell-tags vscode-jupyter-slideshow
                datawrangler
              ]);
          extraFlags = builtins.concatStringsSep " " inputs.config.nixos.packages.packages._vscodeEnvFlags;
        }
      )];
    };
  };
}
