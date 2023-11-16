inputs:
  let
    allUsers =
    {
      root =
      {
        users.users.root =
        {
          shell = inputs.pkgs.zsh;
          autoSubUidGidRange = true;
          hashedPassword = "$y$j9T$.UyKKvDnmlJaYZAh6./rf/$65dRqishAiqxCE6LEMjqruwJPZte7uiyYLVKpzdZNH5";
          openssh.authorizedKeys.keys =
          [
            (builtins.concatStringsSep ""
            [
              "sk-ssh-ed25519@openssh.com "
              "AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIEU/JPpLxsk8UWXiZr8CPNG+4WKFB92o1Ep9OEstmPLzAAAABHNzaDo= "
              "chn@pc"
            ])
          ];
        };
        home-manager.users.root =
        {
          imports = inputs.config.nixos.users.sharedModules;
          config.programs.git =
          {
            extraConfig.core.editor = inputs.lib.mkForce "vim";
            userName = "chn";
            userEmail = "chn@chn.moe";
          };
        };
      };
      chn =
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
          imports = inputs.config.nixos.users.sharedModules;
          config =
          {
            programs =
            {
              git =
              {
                userName = "chn";
                userEmail = "chn@chn.moe";
              };
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
                xmupc1 =
                {
                  host = "xmupc1";
                  hostname = "office.chn.moe";
                  user = "chn";
                  port = 6007;
                };
                nas =
                {
                  host = "nas";
                  hostname = "office.chn.moe";
                  user = "chn";
                  port = 5440;
                };
                xmupc1-ext =
                {
                  host = "xmupc1-ext";
                  hostname = "vps3.chn.moe";
                  user = "chn";
                  port = 6007;
                };
                xmuhk =
                {
                  host = "xmuhk";
                  hostname = "10.26.14.56";
                  user = "xmuhk";
                  # identityFile = "~/.ssh/xmuhk_id_rsa";
                };
                xmuhk2 =
                {
                  host = "xmuhk2";
                  hostname = "183.233.219.132";
                  user = "xmuhk";
                  port = 62022;
                };
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
      xll =
      {
        users.users.xll =
        {
          isNormalUser = true;
          extraGroups = inputs.lib.intersectLists
            [ "groupshare" "video" ]
            (builtins.attrNames inputs.config.users.groups);
          passwordFile = inputs.config.sops.secrets."users/xll".path;
          openssh.authorizedKeys.keys = [ (builtins.readFile ./xll_id_rsa.pub) ];
          shell = inputs.pkgs.zsh;
          autoSubUidGidRange = true;
        };
        home-manager.users.xll.imports = inputs.config.nixos.users.sharedModules;
        sops.secrets."users/xll".neededForUsers = true;
        nixos.services.groupshare.mountPoints = [ "/home/xll/groupshare" ];
      };
      zem =
      {
        users.users.zem =
        {
          isNormalUser = true;
          extraGroups = inputs.lib.intersectLists
            [ "groupshare" "video" ]
            (builtins.attrNames inputs.config.users.groups);
          passwordFile = inputs.config.sops.secrets."users/zem".path;
          openssh.authorizedKeys.keys = [ (builtins.readFile ./zem_id_rsa.pub) ];
          shell = inputs.pkgs.zsh;
          autoSubUidGidRange = true;
        };
        home-manager.users.zem.imports = inputs.config.nixos.users.sharedModules;
        sops.secrets."users/zem".neededForUsers = true;
        nixos.services.groupshare.mountPoints = [ "/home/zem/groupshare" ];
      };
      yjq =
      {
        users.users.yjq =
        {
          isNormalUser = true;
          extraGroups = inputs.lib.intersectLists
            [ "groupshare" "video" ]
            (builtins.attrNames inputs.config.users.groups);
          passwordFile = inputs.config.sops.secrets."users/yjq".path;
          openssh.authorizedKeys.keys = [ (builtins.readFile ./yjq_id_rsa.pub) ];
          shell = inputs.pkgs.zsh;
          autoSubUidGidRange = true;
        };
        home-manager.users.yjq.imports = inputs.config.nixos.users.sharedModules;
        sops.secrets."users/yjq".neededForUsers = true;
        nixos.services.groupshare.mountPoints = [ "/home/yjq/groupshare" ];
      };
      yxy =
      {
        users.users.yxy =
        {
          isNormalUser = true;
          extraGroups = inputs.lib.intersectLists
            [ "groupshare" "video" ]
            (builtins.attrNames inputs.config.users.groups);
          passwordFile = inputs.config.sops.secrets."users/yxy".path;
          openssh.authorizedKeys.keys = [ (builtins.readFile ./yxy_id_rsa.pub) ];
          shell = inputs.pkgs.zsh;
          autoSubUidGidRange = true;
        };
        home-manager.users.yxy.imports = inputs.config.nixos.users.sharedModules;
        sops.secrets."users/yxy".neededForUsers = true;
        nixos.services.groupshare.mountPoints = [ "/home/yxy/groupshare" ];
      };
    };
  in
  {
    options.nixos.users = let inherit (inputs.lib) mkOption types; in
    {
      users = mkOption { type = types.listOf (types.enum (builtins.attrNames allUsers)); default = [ "root" "chn" ]; };
      sharedModules = mkOption { type = types.listOf types.anything; default = []; };
    };
    config =
      let
        inherit (builtins) map attrNames;
        inherit (inputs.lib) mkMerge mkIf;
        inherit (inputs.config.nixos) users;
      in mkMerge
      [
        (mkMerge (map (user: mkIf (builtins.elem user users.users) allUsers.${user}) (attrNames allUsers)))
      ];
  }

# environment.persistence."/impermanence".users.chn =
# {
#   directories =
#   [
#     "Desktop"
#     "Documents"
#     "Downloads"
#     "Music"
#     "repo"
#     "Pictures"
#     "Videos"

#     ".cache"
#     ".config"
#     ".gnupg"
#     ".local"
#     ".ssh"
#     ".android"
#     ".exa"
#     ".gnome"
#     ".Mathematica"
#     ".mozilla"
#     ".pki"
#     ".steam"
#     ".tcc"
#     ".vim"
#     ".vscode"
#     ".Wolfram"
#     ".zotero"

#   ];
#   files =
#   [
#     ".bash_history"
#     ".cling_history"
#     ".gitconfig"
#     ".gtkrc-2.0"
#     ".root_hist"
#     ".viminfo"
#     ".zsh_history"
#   ];
# };
