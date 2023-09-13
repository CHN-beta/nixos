inputs:
{
  options.nixos.services.groupshare = let inherit (inputs.lib) mkOption types; in
  {
    enable = mkOption { type = types.bool; default = false; };
    # hard to read value from inputs.config.users.users.xxx.home, causing infinite recursion
    mountPoints = mkOption { type = types.listOf types.str; default = []; };
  };
  config =
    let
      inherit (inputs.lib) mkIf;
      inherit (builtins) listToAttrs map concatLists;
      inherit (inputs.config.nixos.services) groupshare;
      users = inputs.config.users.groups.groupshare.members;
    in mkIf groupshare.enable
    {
      users.groups.groupshare = {};
      systemd.tmpfiles.rules = [ "d /var/lib/groupshare" ]
        ++ (concatLists (map
          (user:
          [
            "d /var/lib/groupshare/${user} 7750 ${user} groupshare"
            # systemd 253 does not support 'X' bit, it should be manually set
            # sudo setfacl -m 'xxx' dir
            # ("a /var/lib/groupshare/${user} - - - - "
            #   + "d:u:${user}:rwX,u:${user}:rwX,d:g:groupshare:r-X,g:groupshare:r-X,d:o::---,o::---")
          ])
          users));
      fileSystems = listToAttrs (map
        (mountPoint:
        {
          name = mountPoint;
          value = { device = "/var/lib/groupshare"; options = [ "bind" ]; depends = [ "/home" "/var/lib" ]; };
        })
        groupshare.mountPoints);
    };
}
