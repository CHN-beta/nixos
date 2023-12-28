inputs:
{
  config =
    let
      inherit (inputs.lib) mkIf;
    in mkIf (builtins.elem "server" inputs.config.nixos.packages._packageSets)
    {
      nixos.users.sharedModules = [(home-inputs:
      {
        config =
        {
          programs.zsh =
          {
            enable = true;
            initExtraBeforeCompInit =
            ''
              # p10k instant prompt
              P10K_INSTANT_PROMPT="$XDG_CACHE_HOME/p10k-instant-prompt-''${(%):-%n}.zsh"
              [[ ! -r "$P10K_INSTANT_PROMPT" ]] || source "$P10K_INSTANT_PROMPT"
              HYPHEN_INSENSITIVE="true"
              export PATH=~/bin:$PATH
              function br
              {
                local cmd cmd_file code
                cmd_file=$(mktemp)
                if broot --outcmd "$cmd_file" "$@"; then
                  cmd=$(<"$cmd_file")
                  command rm -f "$cmd_file"
                  eval "$cmd"
                else
                  code=$?
                  command rm -f "$cmd_file"
                  return "$code"
                fi
              }
              alias todo="todo.sh"

              bindkey '^X' create_completion
            '';
            plugins =
            [
              {
                file = "powerlevel10k.zsh-theme";
                name = "powerlevel10k";
                src = "${inputs.pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k";
              }
              {
                file = "p10k.zsh";
                name = "powerlevel10k-config";
                src = ./p10k-config;
              }
              {
                name = "zsh-lsd";
                src = inputs.pkgs.fetchFromGitHub
                {
                  owner = "z-shell";
                  repo = "zsh-lsd";
                  rev = "65bb5ac49190beda263aae552a9369127961632d";
                  hash = "sha256-JSNsfpgiqWhtmGQkC3B0R1Y1QnDKp9n0Zaqzjhwt7Xk=";
                };
              }
            ];
            history =
            {
              path = "${home-inputs.config.xdg.dataHome}/zsh/zsh_history";
              extended = true;
              save = 100000000;
              size = 100000000;
            };
          };
          home.file.".config/openaiapirc".source =
            home-inputs.config.lib.file.mkOutOfStoreSymlink inputs.config.sops.templates."zsh/codex".path;
        };
      })];
      programs.zsh =
      {
        enable = true;
        syntaxHighlighting.enable = true;
        autosuggestions.enable = true;
        enableCompletion = true;
        ohMyZsh =
        {
          enable = true;
          plugins = [ "git" "colored-man-pages" "extract" "history-substring-search" "autojump" "zsh_codex" ];
          customPkgs =
          [
            (
              let python = inputs.pkgs.python3.withPackages (ps: with ps; [ ps.openai ]);
              in inputs.pkgs.stdenv.mkDerivation 
              {
                name = "zsh-codex";
                src = inputs.pkgs.fetchFromGitHub
                {
                  owner = "tom-doerr";
                  repo = "zsh_codex";
                  rev = "ce547d610222d98f46f3b496df52c21f13074108";
                  hash = "sha256-pQWEj1PbKVd/+UMT+4JhyJUrLO1aAdbnPRQR0DJ/Iao=";
                };
                dontBuild = true;
                buildInputs = [ python ];
                installPhase =
                ''
                  mkdir -p $out/share/zsh/plugins/zsh_codex
                  cp -r * $out/share/zsh/plugins/zsh_codex
                '';
              }
            )
          ];
        };
      };
      sops =
      {
        templates."zsh/codex" =
        {
          mode = "0444";
          content =
          ''
            [openai]
            organization_id=
            secret_key=${inputs.config.sops.placeholder."zsh/codex-key"}
          '';
        };
        secrets."zsh/codex-key" = {};
      };
    };
}
