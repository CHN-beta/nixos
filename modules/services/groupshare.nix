inputs:
{
  options.nixos.services.groupshare = let inherit (inputs.lib) mkOption types; in
  {
    enable = mkOption { type = types.bool; default = false; };
  };
  config =
    let
      inherit (inputs.lib) mkIf;
      inherit (builtins) listToAttrs map concatLists concatStringsSep;
      inherit (inputs.config.nixos.services) groupshare;
      users = inputs.config.users.groups.groupshare.members;
    in mkIf groupshare.enable
    {
      users.groups.groupshare.gid = inputs.config.nixos.system.user.group.groupshare;
      systemd.tmpfiles.rules = [ "d /var/lib/groupshare" ]
        ++ (concatLists (map
          (user:
          [
            "d /var/lib/groupshare/${user} 2750 ${user} groupshare"
            "Z /var/lib/groupshare/${user} - ${user} groupshare"
            ("A /var/lib/groupshare/${user} - - - - "
              # d 指 default, 即目录下新创建的文件和目录的权限
              # 大写 X 指仅给目录执行权限
              # m 指 mask, 即对于所有者以外的用户, 该用户的权限最大为 m 指定的权限
              + (concatStringsSep "," (concatLists (map
                (perm: [ "d:${perm}" perm ])
                [ "u:${user}:rwX" "g:groupshare:r-X" "o::---" "m::r-x" ]))))
          ])
          users));
    };
}
