inputs:
  let
    inherit (builtins) map attrNames;
    inherit (inputs.lib) mkMerge mkIf mkOption types;
    users =
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
        home-manager.users.root.programs.git =
        {
          extraConfig.core.editor = inputs.lib.mkForce "vim";
          userName = "chn";
          userEmail = "chn@chn.moe";
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
            ("sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIPLByi05vCA95EfpgrCIXzkuyUWsyh"
              + "+Vso8FsUNFwPXFAAAABHNzaDo= chn@chn.moe")
          ];
        };
        home-manager.users.chn.programs =
        {
          git =
          {
            userName = "chn";
            userEmail = "chn@chn.moe";
          };
          ssh.matchBlocks = builtins.listToAttrs
          (
            (map
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
                nas = "192.168.1.185";
              }))
            ++ (map
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
        nixos.services.groupshare.mountPoints = [ "/home/chn/groupshare" ];
      };
      xll =
      {
        users.users.xll =
        {
          isNormalUser = true;
          extraGroups = inputs.lib.intersectLists
            [ "groupshare" ]
            (builtins.attrNames inputs.config.users.groups);
          passwordFile = inputs.config.sops.secrets."users/xll".path;
          shell = inputs.pkgs.zsh;
          autoSubUidGidRange = true;
        };
        sops.secrets."users/xll".neededForUsers = true;
        nixos.services.groupshare.mountPoints = [ "/home/xll/groupshare" ];
      };
    };
  in
  {
    options.nixos.users = mkOption { type = types.listOf (types.enum (attrNames users)); default = [ "root" "chn" ]; };
    config = mkMerge (map (user: mkIf (builtins.elem user inputs.config.nixos.users) users.${user}) (attrNames users));
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