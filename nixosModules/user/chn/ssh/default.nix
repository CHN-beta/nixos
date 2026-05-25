{ config, lib, self, ... }:
{
  config = lib.mkIf (builtins.elem "chn" config.nixos.user.users)
  {
    home-manager.users.chn = homeInputs:
    {
      config =
      {
        programs.ssh =
        {
          settings =
          {
            xmuhk = { HostName = "10.26.14.64"; User = "xmuhk"; };
            xmuhk2 = { HostName = "183.233.219.132"; User = "xmuhk"; Port = 62022; };
            xmuhk2.SetEnv.TERM = "chn_unset_ls_colors:chn_cd:linwei/chn:xterm-256color";
            wlin.SetEnv.TERM = "xterm-256color";
            hwang.SetEnv.TERM = "xterm-256color";
          };
          extraConfig = lib.mkIf config.nixos.model.private
          ''
            IdentityFile ~/.ssh/id_rsa
            IdentityFile ~/.ssh/xmuhk_id_rsa
            IdentityFile ~/.ssh/id_ed25519_sk
          '';
        };
        home.file = lib.mkIf config.nixos.model.private
        (
          {
            ".ssh/id_rsa.pub".source = ./id_rsa.pub;
            ".ssh/id_ed25519.pub".source = ./id_ed25519.pub;
            ".ssh/id_ed25519_sk.pub".source = "${self}/nixosModules/user/keys/chn";
          }
          // (builtins.listToAttrs (builtins.map
            (type:
            {
              name = ".ssh/id_${type}";
              value.source = homeInputs.config.lib.file.mkOutOfStoreSymlink
                config.nixos.system.sops.secrets."chn/${type}".path;
            })
            [ "rsa" "rsa.ppk" "ed25519" "ed25519_sk" ]
          ))
          // {
            ".ssh/xmuhk_id_rsa".source =
              homeInputs.config.lib.file.mkOutOfStoreSymlink config.nixos.system.sops.secrets."chn/xmuhk".path;
          }
        );
      };
    };
    nixos.system.sops.secrets = lib.mkIf config.nixos.model.private (lib.mkMerge
    [
      (builtins.listToAttrs (builtins.map
        (name: lib.nameValuePair "chn/${name}" { owner = "chn"; })
        [ "rsa" "rsa.ppk" "ed25519" "ed25519_sk" "xmuhk" ]))
      { "root/ed25519_sk".key = "chn/ed25519_sk"; }
    ]);
  };
}
