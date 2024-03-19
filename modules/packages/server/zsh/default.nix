inputs:
{
  config =
    let
      inherit (inputs.lib) mkIf;
    in mkIf (builtins.elem "server" inputs.config.nixos.packages._packageSets)
    {
      nixos.user.sharedModules = [(home-inputs: { config.programs =
      {
        zsh =
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
        # set bash history file path, avoid overwriting zsh history
        bash = { enable = true; historyFile =  "${home-inputs.config.xdg.dataHome}/bash/bash_history"; };
      };})];
      programs.zsh =
      {
        enable = true;
        syntaxHighlighting.enable = true;
        autosuggestions.enable = true;
        enableCompletion = true;
        ohMyZsh =
        {
          enable = true;
          plugins = [ "git" "colored-man-pages" "extract" "history-substring-search" "autojump" ];
        };
      };
    };
}
