inputs:
{
  config = inputs.lib.mkMerge
  [
    # for cluster master, export NFS
    (inputs.lib.mkIf (inputs.config.nixos.model.cluster.nodeType or null == "master")
      { nixos.services.nfs."/nix/persistent/home" = "192.168.178.0/24"; })
    # for cluster worker, mount nfs, disable some home manager files
    (inputs.lib.mkIf (inputs.config.nixos.model.cluster.nodeType or null == "worker")
      { nixos.system.fileSystems.mount.nfs."192.168.178.1:/nix/persistent/home" = "/remote/home"; })
    # 将一部分由 home-manager 生成软链接的文件改为直接挂载，以兼容集群的设置
    (let files = [ ".zshrc" ".zshenv" ".profile" ".bashrc" ".bash_profile" ".zlogin" ]; in
    {
      home-manager.users = builtins.listToAttrs (builtins.map
        (user:
        {
          name = user;
          value.config.home.file =
            builtins.listToAttrs (builtins.map (file: { name = file; value.enable = false; }) files);
        })
        inputs.config.nixos.user.users);
      systemd.mounts = builtins.concatLists (builtins.map
        (user: builtins.map
          (file:
          {
            what = "${inputs.config.home-manager.users.${user}.home.file.${file}.source}";
            where = "/home/${user}/${file}";
            options = "bind";
            wantedBy = [ "local-fs.target" ];
          })
          files
        )
        inputs.config.nixos.user.users);
    })
  ];
}
