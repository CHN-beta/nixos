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
    manual = mkOption
    {
      type = types.nullOr (types.attrsOf (types.submodule { options =
      {
        mapper = mkOption { type = types.nonEmptyStr; };
        ssd = mkOption { type = types.bool; default = false; };
      };}));
      default = null;
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
    (inputs.lib.mkIf (luks.manual != null)
    {
      boot.initrd =
      {
        luks.forceLuksSupportInInitrd = true;
        systemd =
        {
          services.wait-manual-decrypt =
          {
            wantedBy = [ "initrd-root-fs.target" ];
            before = [ "roll-rootfs.service" ];
            unitConfig.DefaultDependencies = false;
            serviceConfig.Type = "oneshot";
            script = builtins.concatStringsSep "\n" (builtins.map
              (device: "while [ ! -e /dev/mapper/${device.value.mapper} ]; do sleep 1; done")
              (inputs.lib.attrsToList luks.manual));
          };
          extraBin.cryptsetup = "${inputs.pkgs.cryptsetup}/bin/cryptsetup";
        };
      };
    })
  ];
}
