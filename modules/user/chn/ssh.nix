inputs:
{
  config = let inherit (inputs.config.nixos) user; in inputs.lib.mkIf (builtins.elem "chn" user.users)
  {
    home-manager.users.chn = homeInputs:
    {
      config =
      {
        programs.ssh =
        {
          matchBlocks = rec
          {
            xmuhk = { host = "xmuhk"; hostname = "10.26.14.56"; user = "xmuhk"; };
            xmuhk2 = { host = "xmuhk2"; hostname = "183.233.219.132"; user = "xmuhk"; port = 62022; };
            jykang.setEnv.TERM = "chn_unset_ls_colors:chn_cd:linwei/chn:xterm-256color";
            "wg0.jykang" = jykang;
          }
          // (builtins.listToAttrs (builtins.map
            (system: { name = system; value = { forwardAgent = true; extraOptions.AddKeysToAgent = "yes"; }; })
            [
              "vps6" "wg0.vps6" "vps7" "wg0.vps7" "wg0.pc" "nas" "wg0.nas" "pc"
              "srv1" "wg0.srv1" "srv2" "wg0.srv2" "one" "wg0.one"
            ]));
          extraConfig = inputs.lib.mkIf inputs.config.nixos.model.private
          ''
            IdentityFile ~/.ssh/id_rsa
            IdentityFile ~/.ssh/xmuhk_id_rsa
            IdentityFile ~/.ssh/id_ed25519_sk
          '';
        };
        home.file = inputs.lib.mkIf inputs.config.nixos.model.private
        (
          {
            ".ssh/id_rsa.pub".text = "ssh-rsa "
              + "AAAAB3NzaC1yc2EAAAADAQABAAABAQDXlhoouWG+arWJz02vBP/lxpG2tUjx8jhGBnDeNyMu0OtGcnHMAWcb3YDP0A2XJ"
              + "IVFBCCZMM2REwnSNbHRSCl1mTdRbelfjA+7Jqn1wnrDXkAOG3S8WYXryPGpvavu6lgW7p+dIhGiTLWwRbFH+epFTn1hZ3"
              + "A1UofVIWTOPdoOnx6k7DpQtIVMWiIXLg0jIkOZiTMr3jKfzLMBAqQ1xbCV2tVwbEY02yxxyxIznbpSPReyn1RDLWyqqLR"
              + "d/oqGPzzhEXNGNAZWnSoItkYq9Bxh2AvMBihiTir3FEVPDgDLtS5LUpM93PV1yTr6JyCPAod9UAxpfBYzHKse0KCQFoZH"
              + " chn@chn-PC";
            ".ssh/id_ed25519.pub".text =
              "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOH3AvxMlB3omzH6SFQt0Z5+f05x9nMJpFfSLH4OIYV+ chn@pc";
            ".ssh/id_ed25519_sk.pub".source = ./id_ed25519_sk.pub;
          }
          // (builtins.listToAttrs (builtins.map
            (type:
            {
              name = ".ssh/id_${type}";
              value.source = homeInputs.config.lib.file.mkOutOfStoreSymlink
                inputs.config.sops.secrets."chn/${type}".path;
            })
            [ "rsa" "rsa.ppk" "ed25519" "ed25519_sk" ]
          ))
          // {
            ".ssh/xmuhk_id_rsa".source =
              homeInputs.config.lib.file.mkOutOfStoreSymlink inputs.config.sops.secrets."chn/xmuhk".path;
          }
        );
      };
    };
    sops.secrets = inputs.lib.mkIf inputs.config.nixos.model.private (builtins.listToAttrs (builtins.map
      (name:
      {
        name = "chn/${name}";
        value = { owner = "chn"; sopsFile = "${inputs.config.nixos.system.sops.crossSopsDir}/chn.yaml"; };
      })
      [ "rsa" "rsa.ppk" "ed25519" "ed25519_sk" "xmuhk" ]
    ));
  };
}
