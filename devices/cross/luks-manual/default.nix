{ config, lib, ... }:
let devices =
{
  vps4."/dev/disk/by-uuid/bf7646f9-496c-484e-ada0-30335da57068" = { mapper = "root"; ssd = true; };
  vps6."/dev/disk/by-uuid/961d75f0-b4ad-4591-a225-37b385131060" = { mapper = "root"; ssd = true; };
  vps9."/dev/disk/by-partlabel/vps9-root" = { mapper = "root"; ssd = true; };
};
in
{
  config =
  {
    nixos.system.fileSystems.luks.manual =
      let inherit (config.nixos.model) hostname;
      in if devices ? ${hostname} then devices.${hostname} else lib.mkOptionDefault null;
    home-manager.users.chn.config.nixos.decrypt = devices;
  };
}
