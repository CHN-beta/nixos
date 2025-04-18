inputs:
let devices =
{
  nas =
  {
    "/dev/disk/by-uuid/a47f06e1-dc90-40a4-89ea-7c74226a5449".mapper = "root3";
    "/dev/disk/by-uuid/b3408fb5-68de-405b-9587-5e6fbd459ea2".mapper = "root4";
    "/dev/disk/by-uuid/a779198f-cce9-4c3d-a64a-9ec45f6f5495" = { mapper = "nix"; ssd = true; };
  };
  vps6."/dev/disk/by-uuid/961d75f0-b4ad-4591-a225-37b385131060" = { mapper = "root"; ssd = true; };
  vps7."/dev/disk/by-uuid/db48c8de-bcf7-43ae-a977-60c4f390d5c4" = { mapper = "root"; ssd = true; };
  srv3."/dev/disk/by-partlabel/srv3-root1" = { mapper = "root1"; ssd = true; };
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
