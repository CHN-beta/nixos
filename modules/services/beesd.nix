inputs:
{
  options.nixos.services.beesd = let inherit (inputs.lib) mkOption types; in mkOption
  {
    type = types.nullOr (types.submodule { options =
    {
      instances = mkOption
      {
        type = types.attrsOf (types.oneOf
        [
          types.nonEmptyStr
          (types.submodule
          {
            options =
            {
              device = mkOption { type = types.nonEmptyStr; };
              hashTableSizeMB = mkOption { type = types.ints.unsigned; default = 1024; };
              threads = mkOption { type = types.ints.unsigned; default = 1; };
            };})
        ]);
        default = {};
      };
    };});
    default = null;
  };
  config = let inherit (inputs.config.nixos.services) beesd; in inputs.lib.mkIf (beesd != null)
  {
    services.beesd.filesystems = builtins.listToAttrs (map
      (instance:
      {
        inherit (instance) name;
        value =
        {
          spec = instance.value.device or instance.value;
          hashTableSizeMB = instance.value.hashTableSizeMB or 1024;
          extraOptions =
          [
            "--workaround-btrfs-send"
            "--thread-count" "${builtins.toString instance.value.threads or 1}"
            "--scan-mode" "3"
          ];
        };
      })
      (inputs.localLib.attrsToList beesd.instances));
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
