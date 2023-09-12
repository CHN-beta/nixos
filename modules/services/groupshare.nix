inputs:
{
  options.nixos.services.groupshare = let inherit (inputs.lib) mkOption types; in
  {
    enable = mkOption { type = types.bool; default = false; };
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
          "d /var/lib/groupshare/${user} 0750 ${user} groupshare"
          "a /var/lib/groupshare/${user} - - - - u::rwX,g::rX,o::r"
        ])
        users));
      fileSystems = listToAttrs (map
        (user:
        {
          name = "${inputs.config.users.users."${user}".home}/share";
          value = { device = "/var/lib/groupshare"; options = [ "bind" ]; };
        })
        users);
    };
}