inputs:
{
  options.nixos.packages.vscode = let inherit (inputs.lib) mkOption types; in mkOption
  {
    type = types.nullOr (types.submodule {});
    default = if inputs.config.nixos.model.type == "desktop" then {} else null;
  };
  config = let inherit (inputs.config.nixos.packages) vscode; in inputs.lib.mkIf (vscode != null)
  {
    nixos.user.sharedModules =
    [(hmInputs: {
      config.programs.vscode = inputs.lib.mkIf (hmInputs.config.home.username != "root")
      {
        enable = true;
        package = inputs.pkgs.vscode.overrideAttrs (prev: { preFixup = prev.preFixup +
        ''
          gappsWrapperArgs+=(
            ${builtins.concatStringsSep " " inputs.config.nixos.packages.packages._vscodeEnvFlags}
          )
        '';});
        profiles.default =
        {
          enableExtensionUpdateCheck = false;
          enableUpdateCheck = false;
          extensions = inputs.pkgs.nix4vscode.forVscode
          [
            "github.copilot" "github.copilot-chat" "github.github-vscode-theme"
            "intellsmi.comment-translate"
            "ms-vscode.cmake-tools" "ms-vscode.cpptools-extension-pack" "ms-vscode.hexeditor"
            "ms-vscode.remote-explorer"
            "ms-vscode-remote.remote-ssh"
            "donjayamanne.githistory" "fabiospampinato.vscode-diff"
            "llvm-vs-code-extensions.vscode-clangd" "ms-ceintl.vscode-language-pack-zh-hans"
            "oderwat.indent-rainbow"
            "guyutongxue.cpp-reference" "thfriedrich.lammps" "leetcode.vscode-leetcode" # "znck.grammarly"
            "james-yu.latex-workshop" "bbenoist.nix" "jnoortheen.nix-ide" "ccls-project.ccls"
            "brettm12345.nixfmt-vscode"
            "gruntfuggly.todo-tree"
            # restrctured text
            "lextudio.restructuredtext" "trond-snekvik.simple-rst" "swyddfa.esbonio" "chrisjsewell.myst-tml-syntax"
            # markdown
            "yzhang.markdown-all-in-one" "shd101wyy.markdown-preview-enhanced"
            # vasp
            "mystery.vasp-support"
            "yutengjing.open-in-external-app"
            # git graph
            "mhutchie.git-graph"
            # python
            "ms-python.python"
            # theme
            "pkief.material-icon-theme"
            # direnv
            "mkhl.direnv"
            # svg viewer
            "vitaliymaz.vscode-svg-previewer"
            # draw
            "pomdtr.excalidraw-editor"
            # typst
            "myriad-dreamin.tinymist"
            # grammaly alternative
            "ltex-plus.vscode-ltex-plus"
            # jupyter
            "ms-toolsai.jupyter" "ms-toolsai.jupyter-keymap" "ms-toolsai.jupyter-renderers"
            "ms-toolsai.vscode-jupyter-cell-tags" "ms-toolsai.vscode-jupyter-slideshow"
            "ms-toolsai.datawrangler"
            # nushell
            "TheNuProjectContributors.vscode-nushell-lang"
          ];
          keybindings =
          [
            # use alt+a to complete inline suggestions, instead of tab or ctrl+enter
            {
              key = "alt+a";
              command = "editor.action.inlineSuggest.commit";
              when = "inlineSuggestionVisible";
            }
            {
              key = "tab";
              command = "-editor.action.inlineSuggest.commit";
            }
            {
              key = "ctrl+enter";
              command = "-editor.action.inlineSuggest.commit";
            }
            # use ctrl+j to jump to pdf in latex
            {
              key = "ctrl+alt+j";
              command = "-latex-workshop.synctex";
            }
            {
              key = "ctrl+j";
              command = "-workbench.action.togglePanel";
            }
            {
              key = "ctrl+j";
              command = "latex-workshop.synctex";
              when = "editorTextFocus && editorLangId == 'latex'";
            }
            {
              key = "ctrl+l alt+j";
              command = "-latex-workshop.synctex";
            }
            # use ctrl+j=b to build latex
            {
              key = "ctrl+b";
              command = "-workbench.action.toggleSidebarVisibility";
            }
            {
              key = "ctrl+b";
              command = "latex-workshop.build";
              when = "editorLangId =~ /^latex$|^latex-expl3$|^rsweave$|^jlweave$|^pweave$/";
            }
            {
              key = "ctrl+l alt+b";
              command = "-latex-workshop.build";
            }
            # use alt+t to cd to current dir
            {
              key = "alt+t";
              command = "workbench.action.terminal.sendSequence";
              args.text = "cd '\${fileDirname}'\n";
            }
          ];
          userSettings =
          {
            "security.workspace.trust.enabled" = false;
            "editor.fontFamily" = "'FiraCode Nerd Font Mono', 'Noto Sans Mono CJK SC', 'Droid Sans Mono', 'monospace', monospace, 'Droid Sans Fallback'";
            "editor.fontLigatures" = true;
            "workbench.iconTheme" = "material-icon-theme";
            "cmake.configureOnOpen" = true;
            "editor.mouseWheelZoom" = true;
            "extensions.ignoreRecommendations" = true;
            "editor.smoothScrolling" = true;
            "editor.cursorSmoothCaretAnimation" = "on";
            "workbench.list.smoothScrolling" = true;
            "files.hotExit" = "off";
            "editor.wordWrapColumn" = 120;
            "window.restoreWindows" = "none";
            "editor.inlineSuggest.enabled" = true;
            "github.copilot.enable"."*" = true;
            "editor.acceptSuggestionOnEnter" = "off";
            "terminal.integrated.scrollback" = 10000;
            "editor.rulers" = [ 120 ];
            "indentRainbow.ignoreErrorLanguages" = [ "*" ];
            "markdown.extension.completion.respectVscodeSearchExclude" = false;
            "markdown.extension.print.absoluteImgPath" = false;
            "editor.tabCompletion" = "on";
            "workbench.colorTheme" = "GitHub Light";
            "workbench.startupEditor" = "none";
            "debug.toolBarLocation" = "docked";
            "search.maxResults" = 100000;
            "editor.action.inlineSuggest.commit" = "Ctrl+Space";
            "window.dialogStyle" = "custom";
            "redhat.telemetry.enabled" = true;
            "[xml]"."editor.defaultFormatter" = "DotJoshJohnson.xml";
            "git.ignoreLegacyWarning" = true;
            "git.confirmSync" = false;
            "cmake.configureArgs" = [ "-DCMAKE_VERBOSE_MAKEFILE:BOOL=ON" "-DCMAKE_EXPORT_COMPILE_COMMANDS=1" ];
            "editor.wordWrap" = "wordWrapColumn";
            "files.associations" = { "POSCAR" = "poscar"; "*.mod" = "lmps"; "*.vasp" = "poscar"; };
            "editor.stickyScroll.enabled" = true;
            "editor.minimap.showSlider" = "always";
            "editor.unicodeHighlight.allowedLocales" = { "zh-hans" = true; "zh-hant" = true; };
            "hexeditor.columnWidth" = 64;
            "latex-workshop.synctex.afterBuild.enabled" = true;
            "hexeditor.showDecodedText" = true;
            "hexeditor.defaultEndianness" = "little";
            "hexeditor.inspectorType" = "aside";
            "commentTranslate.hover.concise" = true;
            "commentTranslate.targetLanguage" = "en";
            "[python]"."editor.formatOnType" = true;
            "editor.minimap.renderCharacters" = false;
            "update.mode" = "none";
            "editor.tabSize" = 2;
            "nix.enableLanguageServer" = true;
            "nix.serverPath" = "nil";
            "nix.formatterPath" = "nixpkgs-fmt";
            "nix.serverSettings"."nil" =
            {
              "diagnostics"."ignored" = [ "unused_binding" "unused_with" ];
              "formatting"."command" = [ "nixpkgs-fmt" ];
            };
            "xmake.envBehaviour" = "erase";
            "git.openRepositoryInParentFolders" = "never";
            "todo-tree.regex.regex" = "(//|#|<!--|;|/\\*|^|%|^[ \\t]*(-|\\d+.))\\s*($TAGS)";
            "latex-workshop.latex.recipes" =
            [
              {
                name = "xelatex";
                tools = [ "xelatex" "bibtex" "xelatex" "xelatex" ];
              }
              {
                name = "latexmk";
                tools = [ "latexmk" ];
              }
              {
                name = "latexmk (latexmkrc)";
                tools = [ "latexmk_rconly" ];
              }
              {
                name = "latexmk (lualatex)";
                tools = [ "lualatexmk" ];
              }
              {
                name = "latexmk (xelatex)";
                tools = [ "xelatexmk" ];
              }
              {
                name = "pdflatex -> bibtex -> pdflatex * 2";
                tools = [ "pdflatex" "bibtex" "pdflatex" "pdflatex" ];
              }
            ];
            "latex-workshop.latex.recipe.default" = "xelatex";
            "latex-workshop.bind.altKeymap.enabled" = true;
            "latex-workshop.latex.autoBuild.run" = "never";
            "cmake.showOptionsMovedNotification" = false;
            "markdown.extension.toc.plaintext" = true;
            "markdown.extension.katex.macros" = {};
            "markdown-preview-enhanced.mathRenderingOption" = "MathJax";
            "mesonbuild.downloadLanguageServer" = false;
            "genieai.openai.model" = "gpt-3.5-turbo-instruct";
            "codeium.enableConfig" = { "*" = true; "Log" = true; };
            "fortran.notifications.releaseNotes" = false;
            "markdown-preview-enhanced.enablePreviewZenMode" = true;
            "ccls.misc.compilationDatabaseDirectory" = "build";
            "C_Cpp.intelliSenseEngine" = "disabled";
            "clangd.arguments" = [ "-header-insertion=never" ];
            "cmake.ctestDefaultArgs" = [ "-T" "test" "--output-on-failure" "--verbose" ];
            "terminal.integrated.mouseWheelZoom" = true;
            "notebook.lineNumbers" = "on";
            "editor.codeActionsOnSave" = {};
            "jupyter.notebookFileRoot" = "\${workspaceFolder}";
            "svg.preview.transparencyGrid" = false;
            "svg.preview.boundingBox" = false;
            "latex-workshop.latex.tools" =
            [
              {
                name = "xelatex";
                command = "xelatex";
                args = [ "-synctex=1" "-interaction=nonstopmode" "-file-line-error" "%DOC%" ];
                env = {};
              }
              {
                name = "latexmk";
                command = "latexmk";
                args = [ "-synctex=1" "-interaction=nonstopmode" "-file-line-error" "-pdf" "-outdir=%OUTDIR%" "%DOC%" ];
                env = {};
              }
              {
                name = "lualatexmk";
                command = "latexmk";
                args =
                  [ "-synctex=1" "-interaction=nonstopmode" "-file-line-error" "-lualatex" "-outdir=%OUTDIR%" "%DOC%" ];
                env = {};
              }
              {
                name = "xelatexmk";
                command = "latexmk";
                args =
                  [ "-synctex=1" "-interaction=nonstopmode" "-file-line-error" "-xelatex" "-outdir=%OUTDIR%" "%DOC%" ];
                env = {};
              }
              {
                name = "latexmk_rconly";
                command = "latexmk";
                args = [ "%DOC%" ];
                env = {};
              }
              {
                name = "pdflatex";
                command = "pdflatex";
                args = [ "-synctex=1" "-interaction=nonstopmode" "-file-line-error" "%DOC%" ];
                env = {};
              }
              {
                name = "bibtex";
                command = "bibtex";
                args = [ "%DOCFILE%" ];
                env = {};
              }
              {
                name = "rnw2tex";
                command = "Rscript";
                args = [ "-e" "knitr::opts_knit$set(concordance = TRUE); knitr::knit('%DOCFILE_EXT%')" ];
                env = {};
              }
              {
                name = "jnw2tex";
                command = "julia";
                args = [ "-e" "using Weave; weave(\"%DOC_EXT%\", doctype=\"tex\")" ];
                env = {};
              }
              {
                name = "jnw2texminted";
                command = "julia";
                args = [ "-e" "using Weave; weave(\"%DOC_EXT%\", doctype=\"texminted\")" ];
                env = {};
              }
              {
                name = "pnw2tex";
                command = "pweave";
                args = [ "-f" "tex" "%DOC_EXT%" ];
                env = {};
              }
              {
                name = "pnw2texminted";
                command = "pweave";
                args = [ "-f" "texminted" "%DOC_EXT%" ];
                env = {};
              }
              {
                name = "tectonic";
                command = "tectonic";
                args = [ "--synctex" "--keep-logs" "--print" "%DOC%.tex" ];
                env = {};
              }
            ];
            "todo-tree.general.tags" = [ "BUG" "HACK" "FIXME" "TODO" ];
            "ltex.additionalRules.motherTongue" = "zh-CN";
            "ltex.ltex-ls.path" = "/run/current-system/sw";
            "cmake.ignoreCMakeListsMissing" = true;
            "[nix]"."editor.defaultFormatter" = "jnoortheen.nix-ide";
            "todo-tree.filtering.excludedWorkspaces" = [ "/nix/remote/**" ];
            "dataWrangler.outputRenderer.enabledTypes" =
            {
              "numpy.ndarray" = true;
              "builtins.list" = true;
              "builtins.dict" = true;
            };
            "ltex.language" = "auto";
            # maybe this could fix typst preview freezing on large project
            "tinymist.preview.partialRendering" = false;
            "tinymist.preview.refresh" = "onSave";
            "workbench.secondarySideBar.defaultVisibility" = "hidden";
          };
        };
      };
    })];
  };
}
