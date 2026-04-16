inputs:
{
  options.nixos.system.fileSystems.luks = let inherit (inputs.lib) mkOption types; in
  {
    auto = mkOption
    {
      type = types.attrsOf (types.submodule { options =
      {
        mapper = mkOption { type = types.nonEmptyStr; };
        ssd = mkOption { type = types.bool; default = false; };
      };});
      default = {};
    };
  };
  config = let inherit (inputs.config.nixos.system.fileSystems) luks; in inputs.lib.mkMerge
  [
    (inputs.lib.mkIf (luks.auto != null) { boot.initrd =
    {
      luks.devices = (builtins.listToAttrs (builtins.map
        (device:
        {
          name = device.value.mapper;
          value =
          {
            device = device.name;
            allowDiscards = device.value.ssd;
            bypassWorkqueues = device.value.ssd;
            crypttabExtraOpts = [ "fido2-device=auto" "x-initrd.attach" ];
          };
        })
        (inputs.lib.attrsToList luks.auto)));
    };})
  ];
}
