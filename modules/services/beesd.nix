inputs:
{
  options.nixos.services.beesd = let inherit (inputs.lib) mkOption types; in mkOption
  {
    type = types.nullOr (types.attrsOf (types.submodule (submoduleInputs:
    {
      options =
      {
        hashTableSizeMB = mkOption { type = types.ints.unsigned; default = 16; };
        threads = mkOption { type = types.ints.unsigned; default = 1; };
        loadAverage = mkOption { type = types.ints.unsigned; default = submoduleInputs.config.threads; };
      };
    })));
    default = null;
  };
  config = let inherit (inputs.config.nixos.services) beesd; in inputs.lib.mkIf (beesd != null)
  {
    services.beesd.filesystems = builtins.listToAttrs (builtins.map
      (fs:
      {
        name = inputs.utils.escapeSystemdPath fs.name;
        value =
        {
          spec = fs.name;
          inherit (fs.value) hashTableSizeMB;
          extraOptions =
          [
            "--workaround-btrfs-send"
            "--thread-count" "${builtins.toString fs.value.threads}"
            "--loadavg-target" "${builtins.toString fs.value.loadAverage}"
            "--scan-mode" "3"
            "--verbose" "4"
          ];
        };
      })
      (inputs.localLib.attrsToList beesd));
    nixos.packages.packages._packages = [ inputs.pkgs.bees ];
  };
}
