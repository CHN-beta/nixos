{ lib, pkgs, ... }:
{
  config =
  {
    nixos.user.sharedModules = [(home-inputs:
    {
      config = lib.mkMerge
      [
        {
          programs.zsh =
          {
            enable = true;
            history =
            {
              path = "${home-inputs.config.xdg.dataHome}/zsh/zsh_history";
              extended = true;
              save = 100000000;
              size = 100000000;
            };
            syntaxHighlighting.enable = true;
            autosuggestion.enable = true;
            enableCompletion = true;
            oh-my-zsh =
            {
              enable = true;
              plugins = [ "git" "colored-man-pages" "extract" "history-substring-search" "autojump" ];
              theme = lib.mkDefault "clean";
            };
            # ensure ~/.zlogin exists
            loginExtra = " ";
          };
          home.shell.enableZshIntegration = true;
        }
        {
          programs =
            let optional = lib.mkIf (builtins.elem home-inputs.config.home.username
              [ "chn" "root" "aleksana" "alikia" "hjp" "lilydjwg" ]);
            in
            {
              zsh = optional
              {
                plugins =
                [
                  {
                    file = "powerlevel10k.zsh-theme";
                    name = "powerlevel10k";
                    src = "${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k";
                  }
                  { file = "p10k.zsh"; name = "powerlevel10k-config"; src = ./p10k-config; }
                  {
                    name = "zsh-lsd";
                    src = pkgs.fetchFromGitHub
                    {
                      owner = "z-shell";
                      repo = "zsh-lsd";
                      rev = "65bb5ac49190beda263aae552a9369127961632d";
                      hash = "sha256-JSNsfpgiqWhtmGQkC3B0R1Y1QnDKp9n0Zaqzjhwt7Xk=";
                    };
                  }
                ];
                initContent = lib.mkOrder 550
                ''
                  # p10k instant prompt
                  P10K_INSTANT_PROMPT="$XDG_CACHE_HOME/p10k-instant-prompt-''${(%):-%n}.zsh"
                  [[ ! -r "$P10K_INSTANT_PROMPT" ]] || source "$P10K_INSTANT_PROMPT"
                  HYPHEN_INSENSITIVE="true"
                  export PATH=~/bin:$PATH
                  zstyle ':vcs_info:*' disable-patterns "/nix/remote/*"
                '';
                oh-my-zsh.theme = "";
              };
              fzf = optional { enable = true; };
            };
        }
      ];
    })];
    environment.pathsToLink = [ "/share/zsh" ];
    programs.zsh.enable = true;
  };
}
