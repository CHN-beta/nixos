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
  config = let inherit (inputs.config.nixos.services) sshd; in inputs.lib.mkIf (sshd != null)
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
    # generate from https://patorjk.com/software/taag with font "BlurVision ASCII"
    # generate using `toilet -f wideterm -F border "InAlGaN / SiC"`
    # somehow lolcat could not run with these characters, use rendered directly
    # TODO: move this settings to user
    users.motdFile = inputs.lib.mkIf sshd.groupBanner ./banner-rendered.txt;
  };
}
