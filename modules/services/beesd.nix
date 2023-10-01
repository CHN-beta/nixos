inputs:
{
  options.nixos.services.beesd = let inherit (inputs.lib) mkOption types; in
  {
    enable = mkOption { type = types.bool; default = false; };
    instances = mkOption
    {
      type = types.attrsOf (types.oneOf
      [
        types.nonEmptyStr
        (types.submodule { options =
        {
          device = mkOption { type = types.nonEmptyStr; };
          hashTableSizeMB = mkOption { type = types.int; };
        };})
      ]);
      default = {};
    };
  };
  config =
    let
      inherit (inputs.config.nixos.services) beesd;
      inherit (inputs.lib) mkIf;
      inherit (builtins) map listToAttrs;
      inherit (inputs.localLib) attrsToList;
    in mkIf beesd.enable
      {
        services.beesd.filesystems = listToAttrs (map
          (instance:
          {
            inherit (instance) name;
            value =
            {
              spec = instance.value.device or instance.value;
              hashTableSizeMB = instance.value.hashTableSizeMB or 1024;
              extraOptions = [ "--thread-count" "1" "--scan-mode" "3" ];
            };
          })
          (attrsToList beesd.instances));
        systemd.slices.system-beesd.sliceConfig =
        {
          CPUSchedulingPolicy = "idle";
          IOSchedulingClass = "idle";
          IOSchedulingPriority = 4;
          IOAccounting = true;
          IOWeight = 1;
          Nice = 19;
        };
      };
}
