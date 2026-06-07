{
  localLib,
  config,
  lib,
  ...
}:
{
  imports = localLib.findModules ./.;
  config = lib.mkIf (builtins.elem "chn" config.nixos.user.users) {
    users.users.chn = {
      extraGroups = lib.intersectLists [
        "adbusers"
        "networkmanager"
        "wheel"
        "wireshark"
        "libvirtd"
        "ipfs"
        "dialout"
      ] (builtins.attrNames config.users.groups);
      subUidRanges = [
        {
          startUid = 100000;
          count = 65536;
        }
      ];
      subGidRanges = [
        {
          startGid = 100000;
          count = 65536;
        }
      ];
      hashedPassword = "$y$j9T$xJwVBoGENJEDSesJ0LfkU1$VEExaw7UZtFyB4VY1yirJvl7qS7oiF49KbEBrV0.hhC";
    };
  };
}
