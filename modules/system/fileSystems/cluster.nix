inputs:
{
  options.nixos.system.fileSystems.cluster = let inherit (inputs.lib) mkOption types; in mkOption
  {
    type = types.nullOr (types.submodule { options =
    {
      masterAddress = mkOption { type = types.str; default = "1"; };
    };});
    default = if inputs.config.nixos.model.cluster != null then {} else null;
  };
  config = inputs.lib.mkMerge
  [
    # 将一部分由 home-manager 生成软链接的文件改为直接挂载，以兼容集群的设置
    (
      let files = user:
      [
        "/home/${user}/.zshrc" "/home/${user}/.zshenv" "/home/${user}/.zlogin"
        ".profile" ".bashrc" ".bash_profile"
      ];
      in
      {
        home-manager.users = builtins.listToAttrs (builtins.map
          (user: inputs.lib.nameValuePair user
          {
            config.home.file = builtins.listToAttrs (builtins.map
              (file: inputs.lib.nameValuePair "${file}" { enable = false; }) (files user));
          })
          inputs.config.nixos.user.users);
        systemd.mounts = builtins.concatLists (builtins.map
          (user: builtins.map
            (file:
            {
              what = "${inputs.config.home-manager.users.${user}.home.file.${file}.source}";
              where = if inputs.lib.strings.hasPrefix "/home" file then file else "/home/${user}/${file}";
              options = "bind";
              wantedBy = [ "local-fs.target" ];
            })
            (files user)
          )
          inputs.config.nixos.user.users);
      }
    )
    (
      let
        fsCluster = inputs.config.nixos.system.fileSystems.cluster;
        inherit (inputs.config.nixos.model) cluster;
      in inputs.lib.mkIf (fsCluster != null)
      {
        nixos =
        {
          services.nfs = inputs.lib.mkIf (cluster.nodeType or null == "master")
            { exports."/" = [ "192.168.178.0/24" ]; };
          system.fileSystems.mount.nfs = inputs.lib.mkIf (cluster.nodeType or null == "worker")
          {
            "192.168.178.${fsCluster.masterAddress}:/" = "/nix/remote/${cluster.clusterName}";
          };
        };
      })
  ];
}
