inputs:
{
  imports = inputs.localLib.findModules ./.;
  config = let inherit (inputs.config.nixos) user; in inputs.lib.mkIf (builtins.elem "chn" user.users)
  {
    users.users.chn =
    {
      extraGroups = inputs.lib.intersectLists
        [ "adbusers" "networkmanager" "wheel" "wireshark" "libvirtd" "ipfs" ]
        (builtins.attrNames inputs.config.users.groups);
      subUidRanges = [{ startUid = 100000; count = 65536; } ];
      subGidRanges = [{ startGid = 100000; count = 65536; } ];
      hashedPassword = "$y$j9T$xJwVBoGENJEDSesJ0LfkU1$VEExaw7UZtFyB4VY1yirJvl7qS7oiF49KbEBrV0.hhC";
    };
    home-manager.users.chn = hmInputs:
    {
      options.nixos.decrypt = inputs.lib.mkOption
      {
        type = inputs.lib.types.attrsOf (inputs.lib.types.attrsOf (inputs.lib.types.submodule { options =
        {
          mapper = inputs.lib.mkOption { type = inputs.lib.types.nonEmptyStr; };
          ssd = inputs.lib.mkOption { type = inputs.lib.types.bool; default = false; };
        };}));
      };
      config.home =
      {
        packages =
        [
          (
            let
              servers = inputs.localLib.attrsToList hmInputs.config.nixos.decrypt;
              cat = "${inputs.pkgs.coreutils}/bin/cat";
              gpg = "${inputs.pkgs.gnupg}/bin/gpg";
              ssh = "${inputs.pkgs.openssh}/bin/ssh";
            # generate using echo -n key | gpg --encrypt --recipient chn > xxx.key
            in inputs.pkgs.writeShellScriptBin "remote-decrypt" (builtins.concatStringsSep "\n"
              (
                (builtins.map (system: builtins.concatStringsSep "\n"
                  [
                    "decrypt-${system.name}() {"
                    "  key=$(${cat} ${inputs.topInputs.self}/devices/cross/luks-manual/${system.name}.key \\"
                    "    | ${gpg} --decrypt)"
                    (builtins.concatStringsSep "\n" (builtins.map
                      (device: "  echo $key | ${ssh} root@initrd.${system.name}.chn.moe cryptsetup luksOpen "
                        + (if device.value.ssd then "--allow-discards " else "")
                        + "${device.name} ${device.value.mapper} -")
                      (inputs.localLib.attrsToList system.value)))
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
