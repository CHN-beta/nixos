{
  lib,
  config,
  pkgs,
  flakeInputs,
  ...
}:
{
  options.nixos.services.sshd = lib.mkOption {
    type = lib.types.nullOr (
      lib.types.submodule {
        options = {
          passwordAuthentication = lib.mkOption {
            type = lib.types.bool;
            default = false;
          };
          groupBanner = lib.mkOption {
            type = lib.types.bool;
            default = false;
          };
          motd = lib.mkOption {
            type = lib.types.bool;
            default = false;
          };
        };
      }
    );
    default = null;
  };
  config =
    let
      inherit (config.nixos.services) sshd;
    in
    lib.mkIf (sshd != null) (
      lib.mkMerge [
        {
          services.openssh = {
            enable = true;
            settings = {
              X11Forwarding = true;
              ChallengeResponseAuthentication = false;
              PasswordAuthentication = sshd.passwordAuthentication;
              KbdInteractiveAuthentication = false;
              UsePAM = true;
              GatewayPorts = "yes";
              StreamLocalBindUnlink = "yes";
            };
          };
        }
        (lib.mkIf sshd.motd {
          nixos.user.sharedModules = [
            (home-inputs: {
              config.programs.zsh.loginExtra = ''
                [ -f /etc/fancy-motd/banner ] && (${lib.getExe pkgs.dotacat} -f /etc/fancy-motd/banner 2> /dev/null)
                motd
              '';
            })
          ];
          # generate from https://patorjk.com/software/taag with font "BlurVision ASCII"
          # generate using `toilet -f wideterm -F border "InAlGaN / SiC"`
          environment = {
            etc = lib.mkIf sshd.groupBanner { "fancy-motd/banner".source = ./banner.txt; };
            systemPackages = [ (pkgs.fancy-motd.overrideAttrs { src = flakeInputs.fancy-motd; }) ];
          };
        })
      ]
    );
}
