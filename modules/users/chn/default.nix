inputs:
{
  config =
    let
      inherit (inputs.lib) mkIf;
      inherit (inputs.config.nixos) users;
    in mkIf (builtins.elem "chn" users.users)
    {
      users.users.chn =
      {
        isNormalUser = true;
        extraGroups = inputs.lib.intersectLists
          [ "adbusers" "networkmanager" "wheel" "wireshark" "libvirtd" "video" "audio" "groupshare" ]
          (builtins.attrNames inputs.config.users.groups);
        shell = inputs.pkgs.zsh;
        autoSubUidGidRange = true;
        hashedPassword = "$y$j9T$xJwVBoGENJEDSesJ0LfkU1$VEExaw7UZtFyB4VY1yirJvl7qS7oiF49KbEBrV0.hhC";
        openssh.authorizedKeys.keys =
        [
          # ykman fido credentials list
          # ykman fido credentials delete f2c1ca2d
          # ssh-keygen -t ed25519-sk -O resident
          # ssh-keygen -K
          (builtins.concatStringsSep ""
          [
            "sk-ssh-ed25519@openssh.com "
            "AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIEU/JPpLxsk8UWXiZr8CPNG+4WKFB92o1Ep9OEstmPLzAAAABHNzaDo= "
            "chn@pc"
          ])
        ];
      };
      home-manager.users.chn =
      {
        imports = users.sharedModules;
        config =
        {
          programs =
          {
            git = { userName = "chn"; userEmail = "chn@chn.moe"; };
            ssh.matchBlocks = builtins.listToAttrs
            (
              (builtins.map
                (host: { name = host; value = { inherit host; hostname = "${host}.chn.moe"; }; })
                [ "internal.pc" "vps5" "vps6" "internal.vps6" "vps7" "internal.vps7" "internal.nas" ])
              ++ (builtins.map
                (host:
                {
                  name = host;
                  value =
                  {
                    host = host;
                    hostname = "hpc.xmu.edu.cn";
                    user = host;
                    extraOptions =
                    {
                      PubkeyAcceptedAlgorithms = "+ssh-rsa";
                      HostkeyAlgorithms = "+ssh-rsa";
                      SetEnv = "TERM=chn_unset_ls_colors:xterm-256color";
                      # in .bash_profile:
                      # if [[ $TERM == chn_unset_ls_colors* ]]; then
                      #   export TERM=${TERM#*:}
                      #   export CHN_LS_USE_COLOR=1
                      # fi
                      # in .bashrc
                      # [ -n "$CHN_LS_USE_COLOR" ] && alias ls="ls --color=auto"
                    };
                  };
                })
                [ "wlin" "jykang" "hwang" ])
            )
            // {
              xmupc1 = { host = "xmupc1"; hostname = "office.chn.moe"; port = 6007; };
              nas = { host = "nas"; hostname = "office.chn.moe"; port = 5440; };
              # identityFile = "~/.ssh/xmuhk_id_rsa";
              xmuhk = { host = "xmuhk"; hostname = "10.26.14.56"; user = "xmuhk"; };
              xmuhk2 = { host = "xmuhk2"; hostname = "183.233.219.132"; user = "xmuhk"; port = 62022; };
            };
          };
          home.packages =
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
          pam.yubico.authorizedYubiKeys.ids = [ "cccccbgrhnub" ];
        };
      };
      nixos.services.groupshare.mountPoints = [ "/home/chn/groupshare" ];
    };
}