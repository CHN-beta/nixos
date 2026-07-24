{
  lib,
  config,
  pkgs,
  ...
}:
{
  options.nixos.system.fileSystems.luks = {
    devices = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            mapper = lib.mkOption { type = lib.types.nonEmptyStr; };
            ssd = lib.mkOption {
              type = lib.types.bool;
              default = false;
            };
            # steps to initlize pkcs11 token:
            # ykman piv keys generate --touch-policy=always -a ECCP256 9d pubkey_9d.pem
            # ykman piv certificates generate --valid-days 3650 -s "CN=YubiKey LUKS" 9d pubkey_9d.pem
            # rm pubkey_9a.pem
            # systemd-cryptenroll --pkcs11-token-uri=list
            # sudo systemd-cryptenroll --pkcs11-token-uri=pkcs11:token=YubiKey%20LUKS /dev/nvme0n1p2
          };
        }
      );
      default = { };
    };
    # disable pkcs11 on desktop,
    # since enabling pkcs11 cause fido2 pin prompt on every device instead of only once
    enablePkcs11 = lib.mkOption {
      type = lib.types.bool;
      default = config.nixos.model.variant != "desktop";
    };
  };
  config =
    let
      inherit (config.nixos.system.fileSystems) luks;
    in
    {
      boot.initrd = {
        luks.devices =
          luks.devices
          |> (lib.mapAttrs' (
            n: v:
            lib.nameValuePair v.mapper {
              device = n;
              allowDiscards = v.ssd;
              bypassWorkqueues = v.ssd;
              crypttabExtraOpts = [
                "x-initrd.attach"
                "token-timeout=1800"
                "fido2-device=auto"
              ]
              ++ lib.optionals luks.enablePkcs11 [ "pkcs11-uri=auto" ];
            }
          ));
        systemd = lib.mkIf (luks != { }) {
          contents."/etc/pkcs11/modules/opensc.module".source =
            config.environment.etc."pkcs11/modules/opensc.module".source;
          storePaths = with pkgs; [
            opensc
            p11-kit
            pcsclite
            pcsclite.lib
            "${config.boot.initrd.systemd.package}/lib/cryptsetup/libcryptsetup-token-systemd-pkcs11.so"
          ];
        };
      };
    };
}
