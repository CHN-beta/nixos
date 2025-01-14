inputs:
{
  config = inputs.lib.mkMerge
  [
    # for cluster master, export NFS
    (inputs.lib.mkIf (inputs.config.nixos.model.cluster.nodeType or null == "master")
      { nixos.services.nfs = { root = "/"; exports = [ "/nix/persistent/home" ]; accessLimit = "192.168.178.0/24"; }; })
    # for cluster worker, mount nfs, disable some home manager files
    (inputs.lib.mkIf (inputs.config.nixos.model.cluster.nodeType or null == "worker")
    {
      nixos.system.fileSystems.mount.nfs = builtins.listToAttrs (builtins.map
        (user: { name = "192.168.178.1:/nix/persistent/home/${user}"; value = "/home/${user}"; })
        inputs.config.nixos.user.users);
    })
    # 将一部分由 home-manager 生成软链接的文件改为直接挂载，以兼容集群的设置
    {
      home-manager.users = builtins.listToAttrs (builtins.map
        (user:
        {
          name = user;
          value.config.home.file = builtins.listToAttrs (builtins.map
            (file: { name = file; value.enable = false; })
            [ ".zshrc" ".zshenv" ".profile" ".bashrc" ".bash_profile" ".zlogin" ]);
        })
        inputs.config.nixos.user.users);
      systemd.mounts = builtins.filter (mount: mount != null) (builtins.concatLists (builtins.map
        (user: builtins.map
          (file:
            let f = inputs.config.home-manager.users.${user}.config.home.file.${file}.source or null;
            in if f == null then null else
            {
              what = "${f}";
              where = "/home/${user}/${file}";
              options = [ "bind" ];
              wantedBy = [ "local-fs.target" ];
            }
          )
          [ ".zshrc" ".zshenv" ".profile" ".bashrc" ".bash_profile" ".zlogin" ]
        )
        inputs.config.nixos.user.users));
    }
  ];
}
