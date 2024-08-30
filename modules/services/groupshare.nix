inputs:
{
  options.nixos.services.groupshare = let inherit (inputs.lib) mkOption types; in mkOption
  {
    type = types.nullOr (types.submodule { options =
    {
      users = mkOption
      {
        type = types.listOf types.nonEmptyStr;
        default = [ "chn" "gb" "xll" "yjq" "zem" "gb" "wp" "hjp" ];
      };
    };});
    default = null;
  };
  config =
    let
      inherit (inputs.config.nixos.services) groupshare;
      users = inputs.lib.intersectLists groupshare.users inputs.config.nixos.user.users;
    in inputs.lib.mkIf (groupshare != null)
    {
      users =
      {
        users = builtins.listToAttrs (map (user: { name = user; value.extraGroups = [ "groupshare" ]; }) users);
        groups.groupshare.gid = inputs.config.nixos.user.gid.groupshare;
      };
      systemd.tmpfiles.rules = [ "d /var/lib/groupshare" ]
        ++ (builtins.concatLists (map
          (user:
          [
            "d /var/lib/groupshare/${user} 2750 ${user} groupshare"
            "Z /var/lib/groupshare/${user} - ${user} groupshare"
            ("A /var/lib/groupshare/${user} - - - - "
              # d 指 default, 即目录下新创建的文件和目录的权限
              # 大写 X 指仅给目录执行权限
              # m 指 mask, 即对于所有者以外的用户, 该用户的权限最大为 m 指定的权限
              + (builtins.concatStringsSep "," (builtins.concatLists (map
                (perm: [ "d:${perm}" perm ])
                [ "u:${user}:rwX" "g:groupshare:r-X" "o::---" "m::r-x" ]))))
          ])
          users));
      home-manager.users = builtins.listToAttrs (map
        (user:
        {
          name = user;
          value = homeInputs:
          {
            config.home.file.groupshare.source = homeInputs.config.lib.file.mkOutOfStoreSymlink "/var/lib/groupshare";
          };
        })
        users);
    };
}
