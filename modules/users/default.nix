inputs:
  let
    allUsers =
    {
      root =
      {
        users.users.root =
        {
          shell = inputs.pkgs.zsh;
          hashedPassword = "$y$j9T$.UyKKvDnmlJaYZAh6./rf/$65dRqishAiqxCE6LEMjqruwJPZte7uiyYLVKpzdZNH5";
          openssh.authorizedKeys.keys =
          [
            ("sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIPLByi05vCA95EfpgrCIXzkuyUWsyh"
              + "+Vso8FsUNFwPXFAAAABHNzaDo= chn@chn.moe")
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
            (builtins.concatStringsSep ""
            [
              "sk-ssh-ed25519@openssh.com "
              "AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIPLByi05vCA95EfpgrCIXzkuyUWsyh+Vso8FsUNFwPXFAAAABHNzaDo= "
              "chn@chn.moe"
            ])
          ];
        };
        home-manager.users.chn =
        {
          imports = inputs.config.nixos.users.sharedModules;
          config.programs =
          {
            git =
            {
              userName = "chn";
              userEmail = "chn@chn.moe";
            };
            ssh.matchBlocks = builtins.listToAttrs
            (
              (builtins.map
                (host:
                {
                  name = host.name;
                  value = { host = host.name; hostname = host.value; user = "chn"; };
                })
                (inputs.localLib.attrsToList
                {
                  vps3 = "vps3.chn.moe";
                  vps4 = "vps4.chn.moe";
                  vps5 = "vps5.chn.moe";
                  vps6 = "vps6.chn.moe";
                  vps7 = "vps7.chn.moe";
                }))
              ++ (builtins.map
                (host:
                {
                  name = host;
                  value =
                  {
                    host = host;
                    hostname = "hpc.xmu.edu.cn";
                    user = host;
                    extraOptions = { PubkeyAcceptedAlgorithms = "+ssh-rsa"; HostkeyAlgorithms = "+ssh-rsa"; };
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