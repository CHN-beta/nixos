inputs:
{
  options.nixos.services.sshd = let inherit (inputs.lib) mkOption types; in
  {
    enable = mkOption { type = types.bool; default = false; };
    passwordAuthentication = mkOption { type = types.bool; default = false; };
  };
  config =
    let
      inherit (inputs.lib) mkIf;
      inherit (inputs.config.nixos.services) sshd;
    in mkIf sshd.enable
    {
      services.openssh =
      {
        enable = true;
        settings =
        {
          X11Forwarding = true;
          TrustedUserCAKeys = "${./ssh-ca.pub}";
          ChallengeResponseAuthentication = false;
          PasswordAuthentication = sshd.passwordAuthentication;
          KbdInteractiveAuthentication = false;
          UsePAM = true;
        };
        extraConfig =
        ''
          Match User root
            PasswordAuthentication no
          Match User chn
            PasswordAuthentication no
        '';
      };
    };
}
