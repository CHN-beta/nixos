{ lib, config, ... }:
{
  options.nixos.system.fileSystems.luks = lib.mkOption
  {
    type = lib.types.attrsOf (lib.types.submodule { options =
    {
      mapper = lib.mkOption { type = lib.types.nonEmptyStr; };
      ssd = lib.mkOption { type = lib.types.bool; default = false; };
      # steps to initlize pkcs11 token:
      # ykman piv keys generate --touch-policy=always -a ECCP256 9d pubkey_9d.pem
      # ykman piv certificates generate --valid-days 3650 -s "CN=YubiKey LUKS" 9d pubkey_9d.pem
      # rm pubkey_9a.pem
      # systemd-cryptenroll --pkcs11-token-uri=list
      # sudo systemd-cryptenroll --pkcs11-token-uri=pkcs11:token=YubiKey%20LUKS /dev/nvme0n1p2
      token = lib.mkOption { type = lib.types.enum [ "fido2" "pkcs11" ]; default = "fido2"; };
    };});
    default = {};
  };
  config = let inherit (config.nixos.system.fileSystems) luks; in
  {
    boot.initrd.luks.devices = luks
      |> (lib.mapAttrs' (n: v: lib.nameValuePair v.mapper
        {
          device = n;
          allowDiscards = v.ssd;
          bypassWorkqueues = v.ssd;
          # otherwise systemd complains: PKCS#11 mode selected but no key file specified, refusing. 
          # keyFile = "none";
          crypttabExtraOpts =
          [
            "x-initrd.attach"
            # { fido2 = "fido2-device=auto"; pkcs11 = "pkcs11-uri=pkcs11:token=YubiKey%20LUKS"; }.${v.token}
            { fido2 = "fido2-device=auto"; pkcs11 = "pkcs11-uri=auto"; }.${v.token}
          ];
        }));
  };
}
