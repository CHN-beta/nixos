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
    services.beesd.filesystems = inputs.lib.mapAttrs'
      (n: v: inputs.lib.nameValuePair (inputs.utils.escapeSystemdPath n)
      {
        spec = n;
        inherit (v) hashTableSizeMB;
        extraOptions =
        [
          "--thread-count" "${builtins.toString v.threads}"
          "--loadavg-target" "${builtins.toString v.loadAverage}"
          "--verbose" "4"
        ];
      })
      beesd;
    environment.systemPackages = [ inputs.pkgs.bees ];
  };
}
