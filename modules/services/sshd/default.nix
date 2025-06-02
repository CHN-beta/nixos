inputs:
{
  options.nixos.services.sshd = let inherit (inputs.lib) mkOption types; in mkOption
  {
    type = types.nullOr (types.submodule { options =
    {
      passwordAuthentication = mkOption { type = types.bool; default = false; };
      groupBanner = mkOption { type = types.bool; default = false; };
    };});
    default = null;
  };
  config = let inherit (inputs.config.nixos.services) sshd; in inputs.lib.mkIf (sshd != null) (inputs.lib.mkMerge
  [
    {
      services.openssh =
      {
        enable = true;
        settings =
        {
          X11Forwarding = true;
          ChallengeResponseAuthentication = false;
          PasswordAuthentication = sshd.passwordAuthentication;
          KbdInteractiveAuthentication = false;
          UsePAM = true;
        };
      };
      nixos.services.xray.client.v2ray-forwarder.noproxyTcpPorts = [ 22 ];
    }
    # 如果是服务器，那么启用 motd
    (inputs.lib.mkIf (inputs.config.nixos.model.type == "server")
    {
      nixos =
      {
        packages.packages._packages =
          [ (inputs.pkgs.fancy-motd.overrideAttrs { src = inputs.topInputs.fancy-motd; }) ];
        user.sharedModules = [(home-inputs: { config.programs.zsh.loginExtra =
        ''
          [ -f /etc/fancy-motd/banner ] && lolcat -f /etc/fancy-motd/banner
          motd
          echo '**维护通知**'
          echo "我计划这周末找个没人用的时间更新一下。大约需要停机半个小时。登陆方式不需要更改。"
          echo "主要的修改包括："
          echo "* 移除了桌面环境。远程桌面没有了。x11 forwarding 还可以用。"
          echo "* 会用另外一个硬盘组 RAID。这样万一某一个硬盘坏了，数据也不会丢失。"
        '';})];
      };
      # generate from https://patorjk.com/software/taag with font "BlurVision ASCII"
      # generate using `toilet -f wideterm -F border "InAlGaN / SiC"`
      environment.etc = inputs.lib.mkIf sshd.groupBanner { "fancy-motd/banner".source = ./banner.txt; };
    })
  ]);
}
