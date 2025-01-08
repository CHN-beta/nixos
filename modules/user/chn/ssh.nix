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
            jykang.setEnv.TERM = "chn_unset_ls_colors:chn_cd:linwei/chn:chn_debug:xterm-256color";
            "wireguard.jykang" = jykang;
          }
          // (builtins.listToAttrs (builtins.map
            (system: { name = system; value = { forwardAgent = true; extraOptions.AddKeysToAgent = "yes"; }; })
            [
              "vps6" "wireguard.vps6" "vps7" "wireguard.vps7" "wireguard.pc" "nas" "wireguard.nas" "pc"
              "xmupc1" "wireguard.xmupc1" "xmupc2" "wireguard.xmupc2" "one" "wireguard.one"
            ]));
          extraConfig = inputs.lib.mkIf inputs.config.nixos.model.private
          ''
            IdentityFile ~/.ssh/id_rsa
            IdentityFile ~/.ssh/xmuhk_id_rsa
            IdentityFile ~/.ssh/id_ed25519_sk
          '';
        };
        home.file = inputs.lib.mkIf inputs.config.nixos.model.private
        {
          ".ssh/id_rsa".source =
            homeInputs.config.lib.file.mkOutOfStoreSymlink inputs.config.sops.secrets."chn/rsa".path;
          ".ssh/id_rsa.pub".text = "ssh-rsa "
            + "AAAAB3NzaC1yc2EAAAADAQABAAABAQDXlhoouWG+arWJz02vBP/lxpG2tUjx8jhGBnDeNyMu0OtGcnHMAWcb3YDP0A2XJ"
            + "IVFBCCZMM2REwnSNbHRSCl1mTdRbelfjA+7Jqn1wnrDXkAOG3S8WYXryPGpvavu6lgW7p+dIhGiTLWwRbFH+epFTn1hZ3"
            + "A1UofVIWTOPdoOnx6k7DpQtIVMWiIXLg0jIkOZiTMr3jKfzLMBAqQ1xbCV2tVwbEY02yxxyxIznbpSPReyn1RDLWyqqLR"
            + "d/oqGPzzhEXNGNAZWnSoItkYq9Bxh2AvMBihiTir3FEVPDgDLtS5LUpM93PV1yTr6JyCPAod9UAxpfBYzHKse0KCQFoZH"
            + " chn@chn-PC";
          ".ssh/id_rsa.ppk".source =
            homeInputs.config.lib.file.mkOutOfStoreSymlink inputs.config.sops.secrets."chn/rsa.ppk".path;
          ".ssh/id_ed25519".source =
            homeInputs.config.lib.file.mkOutOfStoreSymlink inputs.config.sops.secrets."chn/ed25519".path;
          ".ssh/id_ed25519.pub".text =
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOH3AvxMlB3omzH6SFQt0Z5+f05x9nMJpFfSLH4OIYV+ chn@pc";
          ".ssh/id_ed25519_sk".source =
            homeInputs.config.lib.file.mkOutOfStoreSymlink inputs.config.sops.secrets."chn/ed25519_sk".path;
          ".ssh/id_ed25519_sk.pub".source = ./id_ed25519_sk.pub;
          ".ssh/xmuhk_id_rsa".source =
            homeInputs.config.lib.file.mkOutOfStoreSymlink inputs.config.sops.secrets."chn/xmuhk".path;
        };
      };
    };
    sops.secrets = inputs.lib.mkIf inputs.config.nixos.model.private
    {
      "chn/rsa".owner = "chn";
      "chn/rsa.ppk".owner = "chn";
      "chn/ed25519".owner = "chn";
      "chn/ed25519_sk".owner = "chn";
      "chn/xmuhk".owner = "chn";
    };
  };
}
