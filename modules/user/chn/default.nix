inputs:
{
  imports = inputs.localLib.findModules ./.;
  config = let inherit (inputs.config.nixos) user; in inputs.lib.mkIf (builtins.elem "chn" user.users)
  {
    users.users.chn =
    {
      extraGroups = inputs.lib.intersectLists
        [ "adbusers" "networkmanager" "wheel" "wireshark" "libvirtd" ]
        (builtins.attrNames inputs.config.users.groups);
      autoSubUidGidRange = true;
      hashedPassword = "$y$j9T$xJwVBoGENJEDSesJ0LfkU1$VEExaw7UZtFyB4VY1yirJvl7qS7oiF49KbEBrV0.hhC";
      openssh.authorizedKeys.keys = [(builtins.readFile ./id_ed25519_sk.pub)];
    };
    home-manager.users.chn =
    {
      config =
      {
        programs =
        {
          git = { userName = "chn"; userEmail = "chn@chn.moe"; };
          ssh =
          {
            matchBlocks =
            {
              # identityFile = "~/.ssh/xmuhk_id_rsa";
              xmuhk = { host = "xmuhk"; hostname = "10.26.14.56"; user = "xmuhk"; };
              xmuhk2 = { host = "xmuhk2"; hostname = "183.233.219.132"; user = "xmuhk"; port = 62022; };
            }
            // (builtins.listToAttrs (builtins.map
              (system: { name = system; value.forwardAgent = true; })
              [
                "vps6" "wireguard.vps6" "vps7" "wireguard.vps7" "wireguard.pc" "nas" "wireguard.nas" "pc"
                "wireguard.surface" "xmupc1" "wireguard.xmupc1" "xmupc2" "wireguard.xmupc2"
              ]));
            extraConfig =
              inputs.lib.mkIf (builtins.elem inputs.config.nixos.system.networking.hostname [ "pc" "surface" ])
              ''
                IdentityFile ~/.ssh/id_rsa
                IdentityFile ~/.ssh/id_ed25519_sk
              '';
          };
        };
        home =
        {
          file.groupshare.enable = false;
          packages =
          [
            (
              let
                servers = builtins.filter
                  (system: system.value.enable)
                  (builtins.map
                    (system:
                    {
                      name = system.config.nixos.system.networking.hostname;
                      value = system.config.nixos.system.fileSystems.decrypt.manual;
                    })
                    (builtins.attrValues inputs.topInputs.self.nixosConfigurations));
                cat = "${inputs.pkgs.coreutils}/bin/cat";
                gpg = "${inputs.pkgs.gnupg}/bin/gpg";
                ssh = "${inputs.pkgs.openssh}/bin/ssh";
              in inputs.pkgs.writeShellScriptBin "remote-decrypt" (builtins.concatStringsSep "\n"
                (
                  (builtins.map (system: builtins.concatStringsSep "\n"
                    [
                      "decrypt-${system.name}() {"
                      "  key=$(${cat} ${system.value.keyFile} | ${gpg} --decrypt)"
                      (builtins.concatStringsSep "\n" (builtins.map
                        (device: "  echo $key | ${ssh} root@initrd.${system.name}.chn.moe cryptsetup luksOpen "
                          + (if device.value.ssd then "--allow-discards " else "")
                          + "${device.name} ${device.value.mapper} -")
                        (inputs.localLib.attrsToList system.value.devices)))
                      "}"
                    ])
                    servers)
                  ++ [ "decrypt-$1" ]
                ))
            )
          ];
        };
        pam.yubico.authorizedYubiKeys.ids = [ "cccccbgrhnub" ];
      };
    };
    environment.persistence =
      let inherit (inputs.config.nixos.system) impermanence; in inputs.lib.mkIf impermanence.enable
        { "${impermanence.root}".users.chn.directories = [ ".cache" ".config/fontconfig" ]; };
  };
}
