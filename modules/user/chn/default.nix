{ localLib, config, lib, pkgs, topInputs, ... }:
{
  imports = localLib.findModules ./.;
  config = lib.mkIf (builtins.elem "chn" config.nixos.user.users)
  {
    users.users.chn =
    {
      extraGroups = lib.intersectLists
        [ "adbusers" "networkmanager" "wheel" "wireshark" "libvirtd" "ipfs" "dialout" ]
        (builtins.attrNames config.users.groups);
      subUidRanges = [{ startUid = 100000; count = 65536; } ];
      subGidRanges = [{ startGid = 100000; count = 65536; } ];
      hashedPassword = "$y$j9T$xJwVBoGENJEDSesJ0LfkU1$VEExaw7UZtFyB4VY1yirJvl7qS7oiF49KbEBrV0.hhC";
    };
    home-manager.users.chn = hmInputs:
    {
      options.nixos.decrypt = lib.mkOption
      {
        type = lib.types.attrsOf (lib.types.attrsOf (lib.types.submodule { options =
        {
          mapper = lib.mkOption { type = lib.types.nonEmptyStr; };
          ssd = lib.mkOption { type = lib.types.bool; default = false; };
        };}));
      };
      config.home =
      {
        packages =
        [
          (
            let
              servers = localLib.attrsToList hmInputs.config.nixos.decrypt;
              cat = "${pkgs.coreutils}/bin/cat";
              gpg = "${pkgs.gnupg}/bin/gpg";
              ssh = "${pkgs.openssh}/bin/ssh";
            # generate using echo -n key | gpg --encrypt --recipient chn > xxx.key
            in pkgs.writeShellScriptBin "remote-decrypt" (builtins.concatStringsSep "\n"
              (
                (builtins.map (system: builtins.concatStringsSep "\n"
                  [
                    "decrypt-${system.name}() {"
                    "  key=$(${cat} ${topInputs.self}/devices/cross/luks-manual/${system.name}.key \\"
                    "    | ${gpg} --decrypt)"
                    (builtins.concatStringsSep "\n" (builtins.map
                      (device: "  echo $key | ${ssh} root@initrd.${system.name}.chn.moe cryptsetup luksOpen "
                        + (if device.value.ssd then "--allow-discards " else "")
                        + "${device.name} ${device.value.mapper} -")
                      (localLib.attrsToList system.value)))
                    "}"
                  ])
                  servers)
                ++ [ "decrypt-$1" ]
              ))
          )
        ];
      };
    };
  };
}
