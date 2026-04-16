{ lib, config, ... }:
{
  options.nixos.system.fileSystems.luks = lib.mkOption
  {
    type = lib.types.attrsOf (lib.types.submodule { options =
    {
      mapper = lib.mkOption { type = lib.types.nonEmptyStr; };
      ssd = lib.mkOption { type = lib.types.bool; default = false; };
      token = lib.mkOption { type = lib.types.enum [ "fido2" "pkcs11" ]; default = "fido2"; };
    };});
    default = {};
  };
  config = let inherit (config.nixos.system.fileSystems) luks; in { boot.initrd =
  {
    luks.devices = lib.mapAttrs'
      (n: v: lib.nameValuePair v.mapper
      {
        device = n;
        allowDiscards = v.ssd;
        bypassWorkqueues = v.ssd;
        crypttabExtraOpts =
        [
          "x-initrd.attach"
          { fido2 = "fido2-device=auto"; pkcs11 = "pkcs11-uri=auto"; }.${v.token}
        ];
      })
      luks;
  };};
}
