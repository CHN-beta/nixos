inputs:
{
  options.nixos.services.nixvirt = let inherit (inputs.lib) mkOption types; in mkOption
  {
    type = types.nullOr (types.attrsOf (types.submodule
    {
      storage = mkOption { type = types.nonEmptyStr; };
      memoryGB = mkOption { type = types.ints.unsigned; };
      cpus = mkOption { type = types.ints.unsigned; };
      vncPort = mkOption { type = types.ints.unsigned; };
    }));
    default = null;
  };
  config = let inherit (inputs.config.nixos.services) nixvirt; in inputs.lib.mkIf (nixvirt != {})
  {
    # TODO: switch on nixos.virtualisation.kvm
    virtualisation.libvirt =
    {
      enable = true;
      verbose = true;
      connections."qemu:///system" = let inherit (inputs.topInputs.nixvirt) lib; in
      {
        domains =
        [{
          definition = lib.domain.writeXML (lib.domain.templates.linux
          {
            name = "Penguin";
            uuid = "cc7439ed-36af-4696-a6f2-1f0c4474d87e";
            memory = { count = 6; unit = "GiB"; };
            storage_vol = { pool = "MyPool"; volume = "Penguin.qcow2"; };
          });
        }];
        networks =
        [{
          definition = lib.network.writeXML (lib.network.templates.bridge
          {
            uuid = "8f403474-f8d6-4fa7-991a-f62f40d51191";
            subnet_byte = 122;
          });
          active = true;
        }];
        # 不通过它来定义存储，手动控制存储
        pools = null;
      };
    };
  };
}
