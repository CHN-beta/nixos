inputs:
{
  config = inputs.lib.mkIf (builtins.elem "server" inputs.config.nixos.packages._packageSets)
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
        loginExtra =
        ''
          echo -e "\033[33;7m停机维护通知\033[0m"
          echo "我计划在这周的周六或周日，挑一个没有任务在跑的时间进行停机维护。"
          echo -e "\033[33;7m*\033[0m 本次维护需要较长时间（几个小时），期间服务器不可使用。"
          echo -e "\033[33;7m*\033[0m xmupc1 xmupc2将会合并成一个集群（文件互通，投递的任务也互通，例如投递使用4090做计算，则哪个节点的4090空闲就用哪个）。"
          echo -e "\033[33;7m*\033[0m ssh登陆地址改变为：srv2.chn.moe 端口：22 其它登陆参数不变。"
          echo -e "\033[33;7m*\033[0m 我会将每个用户在xmupc1 xmupc2上存储的文件合并到一起。如果同一个用户在xmupc1 xmupc2上有重名的文件夹，我会把它重命名，你登陆后自行整理。"
          echo -e "\033[33;7m*\033[0m 投递任务的命令改变。用鼠标点着投任务的流程不变，但如果是手动敲参数或者写脚本批量投递的，则需要修改。具体怎么改，你可以看文档，也可以用鼠标点着投递一个任务，对照着看。"
          echo -e "\033[33;7m*\033[0m 所有任务信息都会丢失，任务号会从1开始重新数。应该没人在意吧。"
          echo -e "\033[33;7m*\033[0m 没了，重要的应该就这些。"
          echo -e "\033[33;7m*\033[0m 应该没有漏什么了。"
          echo -e "\033[33;7m*\033[0m 其实还解决了这半年累积发现的很多小问题。"
          echo -e "\033[33;7m*\033[0m 我这个公告里有个很常见的错别字，我看看有没有人发现。"
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
