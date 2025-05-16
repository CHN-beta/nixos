inputs:
let devices =
{
  nas =
  {
    "/dev/disk/by-partlabel/nas-root3".mapper = "root3";
    "/dev/disk/by-partlabel/nas-root4".mapper = "root4";
    "/dev/disk/by-partlabel/nas-swap" = { mapper = "swap"; ssd = true; };
  };
  vps4."/dev/disk/by-uuid/bf7646f9-496c-484e-ada0-30335da57068" = { mapper = "root"; ssd = true; };
  vps6."/dev/disk/by-uuid/961d75f0-b4ad-4591-a225-37b385131060" = { mapper = "root"; ssd = true; };
  srv3 =
  {
    "/dev/disk/by-partlabel/srv3-root1" = { mapper = "root1"; ssd = true; };
    "/dev/disk/by-partlabel/srv3-swap" = { mapper = "swap"; ssd = true; };
  };
};
in
{
  config =
  {
    nixos.system.fileSystems.luks.manual =
      let inherit (inputs.config.nixos.model) hostname;
      in if devices ? ${hostname} then devices.${hostname} else inputs.lib.mkOptionDefault null;
    home-manager.users.chn.config.nixos.decrypt = devices;
  };
}
