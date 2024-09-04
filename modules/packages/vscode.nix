inputs:
{
  options.nixos.packages.vscode = let inherit (inputs.lib) mkOption types; in mkOption
  {
    type = types.nullOr (types.submodule {});
    default = if inputs.config.nixos.system.gui.enable then {} else null;
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
                value = nix-vscode-extensions.vscode-marketplace.${set} // vscode-extensions.${set} or {};
              })
              (inputs.lib.unique
              (
                (builtins.attrNames nix-vscode-extensions.vscode-marketplace)
                ++ (builtins.attrNames vscode-extensions)
              )));
            in with extensions;
              (with github; [ copilot github-vscode-theme ])
              ++ (with intellsmi; [ comment-translate ])
              ++ (with ms-vscode; [ cmake-tools cpptools cpptools-extension-pack hexeditor remote-explorer ])
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
              ];
        }
      )];
    };
  };
}
