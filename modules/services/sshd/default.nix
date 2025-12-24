inputs:
{
  options.nixos.services.sshd = let inherit (inputs.lib) mkOption types; in mkOption
  {
    type = types.nullOr (types.submodule { options =
    {
      passwordAuthentication = mkOption { type = types.bool; default = false; };
      groupBanner = mkOption { type = types.bool; default = false; };
      motd = mkOption { type = types.bool; default = false; };
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
          GatewayPorts = "yes";
        };
      };
    }
    (inputs.lib.mkIf sshd.motd
    {
      nixos =
      {
        packages.packages._packages =
          [ (inputs.pkgs.fancy-motd.overrideAttrs { src = inputs.topInputs.fancy-motd; }) ];
        user.sharedModules = [(home-inputs: { config.programs.zsh.loginExtra =
        ''
          [ -f /etc/fancy-motd/banner ] && (lolcat -f /etc/fancy-motd/banner 2> /dev/null)
          motd
        '';})];
      };
      # generate from https://patorjk.com/software/taag with font "BlurVision ASCII"
      # generate using `toilet -f wideterm -F border "InAlGaN / SiC"`
      environment.etc = inputs.lib.mkIf sshd.groupBanner { "fancy-motd/banner".source = ./banner.txt; };
    })
  ]);
}
