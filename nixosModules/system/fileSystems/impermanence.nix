inputs:
{
  options.nixos.system.fileSystems.impermanence = let inherit (inputs.lib) mkOption types; in
  {
    clusterPersistentDirectory = mkOption
    {
      type = types.str;
      default =
        let
          inherit (inputs.config.nixos.model) cluster;
          prefix = if cluster.nodeType or null == "worker" then "/nix/remote/${cluster.clusterName}" else "";
        in "${prefix}/nix/persistent";
      readOnly = true;
    };
  };
  config.environment.persistence = inputs.lib.mkMerge
  [
    # generic settings
    {
      "/nix/persistent" =
      {
        hideMounts = true;
        allowTrash = true;
        directories = [ "/var/db" "/var/lib" "/var/log" "/var/spool" "/var/backup" "/srv" ];
        files = builtins.map (f: "/etc/ssh/ssh_host_${f}_key") [ "ed25519" "rsa" ];
      };
      "/nix/rootfs/current" =
      {
        hideMounts = true;
        allowTrash = true;
        directories = [ "/var/lib/flatpak" ]
          ++ builtins.map (f: "/var/lib/systemd/${f}") [ "linger" "coredump" "backlight" ];
      };
      # TODO: remove in next release
      "/nix/nodatacow" =
      {
        hideMounts = true;
        allowTrash = true;
        directories =
          [{ directory = "/var/log/journal"; user = "root"; group = "systemd-journal"; mode = "u=rwx,g=rx+s,o=rx"; }];
      };
    }
    # 挂载 /home/user
    # 对于集群的工作节点，挂载 /remote/user 到 /home/user
    # 对于桌面用途的 chn，不需要挂载
    # 对于其它情况，则挂载 /nix/persistent/home/user 到 /home/user
    {
      ${inputs.config.nixos.system.fileSystems.impermanence.clusterPersistentDirectory} =
      {
        hideMounts = true;
        allowTrash = true;
        directories = builtins.map
          (user: { directory = "/home/${user}"; inherit user; group = user; mode = "0700"; })
          (builtins.filter
            (user: !(user == "chn" && inputs.config.nixos.model.variant == "desktop"))
            inputs.config.nixos.user.users);
      };
    }
    # 挂载更详细的目录
    # TODO: remove in next release
    # 对于任何情况，`.cache` `.config/systemd` 都应该在重启后丢失
    {
      "/nix/rootfs/current".users = builtins.listToAttrs (builtins.map
        (user: { name = user; value.directories = [ ".cache" ".config/systemd" ]; })
        inputs.config.nixos.user.users);
    }
    # 对于桌面用途的 chn，有一些需要 persist 的目录
    (inputs.lib.mkIf (inputs.config.nixos.model.variant == "desktop")
    {
      "/nix/persistent".users.chn.directories =
      [
        "bin" "Desktop" "Documents" "Downloads" "Music" "Pictures" "repo" "share" "Public" "Videos" ".config"
        ".local" ".ecdata" { directory = ".mozilla/firefox/default"; mode = "0700"; } ".steam" ".zotero"
        "Zotero" ".thunderbird"
        # dms 将剪贴板历史数据和主题的一些设置存放在这里
        ".cache/dms-clipboard" ".cache/DankMaterialShell"
        # gemini-cli
        ".gemini"
      ];
    })
    # 对于集群的工作节点，挂载一些本来由 home-manager 生成的文件，以及一些用来存放 home-manager 生成文件的目录
    # impermanence 挂载来自 nix store 的文件会导致家目录的权限错误，在 cluster.nix 中直接使用 systemd.mounts 来挂载
    (inputs.lib.mkIf (inputs.config.nixos.model.cluster.nodeType or null == "worker")
    {
      "/nix/persistent".users = builtins.listToAttrs (builtins.map
        (user: { name = user; value.directories = [ ".config" ".local" ".ssh" ".mozilla" ".thunderbird" ]; })
        inputs.config.nixos.user.users);
      "/nix/rootfs/current".users = builtins.listToAttrs (builtins.map
        (user: { name = user; value.directories = [ ".zsh" ".yubico" ]; })
        inputs.config.nixos.user.users);
    })
  ];
}
