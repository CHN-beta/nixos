inputs:
{
  options.nixos.services.snapper = let inherit (inputs.lib) mkOption types; in
  {
    enable = mkOption { type = types.bool; default = false; };
    configs = mkOption { type = types.attrsOf types.nonEmptyStr; default.persistent = "/nix/persistent"; };
  };
  config = let inherit (inputs.config.nixos.services) snapper; in inputs.lib.mkIf snapper.enable
  {
    services.snapper.configs = builtins.listToAttrs (builtins.map
      (config:
      {
        inherit (config) name;
        value =
        {
          SUBVOLUME = config.value;
          TIMELINE_CREATE = true;
          TIMELINE_CLEANUP = true;
          TIMELINE_MIN_AGE = 1800;
          TIMELINE_LIMIT_HOURLY = 10;
          TIMELINE_LIMIT_DAILY = 7;
          TIMELINE_LIMIT_WEEKLY = 1;
          TIMELINE_LIMIT_MONTHLY = 0;
          TIMELINE_LIMIT_YEARLY = 0;
        };
      })
      (inputs.localLib.attrsToList snapper.configs));
  };
}
