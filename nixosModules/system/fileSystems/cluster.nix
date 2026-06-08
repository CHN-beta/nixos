{ lib, config, ... }:
{
  options.nixos.system.fileSystems.cluster = lib.mkOption {
    type = lib.types.nullOr (
      lib.types.submodule {
        options = {
          masterAddress = lib.mkOption {
            type = lib.types.str;
            default = "1";
          };
        };
      }
    );
    default = if config.nixos.model.cluster != null then { } else null;
  };
  config = lib.mkMerge [
    # 将一部分由 home-manager 生成软链接的文件改为直接挂载，以兼容集群的设置
    (
      let
        files = user: [
          "./.zshrc"
          "./.zshenv"
          "./.zlogin"
          ".profile"
          ".bashrc"
          ".bash_profile"
        ];
      in
      {
        home-manager.users = builtins.listToAttrs (
          builtins.map (
            user:
            lib.nameValuePair user {
              config.home.file = builtins.listToAttrs (
                builtins.map (file: lib.nameValuePair "${file}" { enable = false; }) (files user)
              );
            }
          ) config.nixos.user.users
        );
        systemd.mounts = builtins.concatLists (
          builtins.map (
            user:
            builtins.map (file: {
              what = "${config.home-manager.users.${user}.home.file.${file}.source}";
              # prepend /. to remove /./ etc from path
              where = lib.toString (
                /. + (if lib.strings.hasPrefix "/home" file then file else "/home/${user}/${file}")
              );
              options = "bind";
              wantedBy = [ "local-fs.target" ];
            }) (files user)
          ) config.nixos.user.users
        );
      }
    )
    (
      let
        fsCluster = config.nixos.system.fileSystems.cluster;
        inherit (config.nixos.model) cluster;
      in
      lib.mkIf (fsCluster != null) {
        nixos = {
          # TODO: master should export /nix/persistent /nix/nodatacow without crossmnt
          services.nfs = lib.mkIf (cluster.nodeType or null == "master") {
            exports."/" = [ "192.168.178.0/24" ];
          };
          system.fileSystems.mount.nfs = lib.mkIf (cluster.nodeType or null == "worker") {
            "192.168.178.${fsCluster.masterAddress}:/" = "/nix/remote/${cluster.clusterName}";
          };
        };
      }
    )
  ];
}
