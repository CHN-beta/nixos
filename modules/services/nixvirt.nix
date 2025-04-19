inputs:
{
  options.nixos.services.nixvirt = let inherit (inputs.lib) mkOption types; in mkOption
  {
    type = types.nullOr (types.attrsOf (types.submodule { options =
    {
      uuid = mkOption { type = types.str; };
      storage = mkOption { type = types.nonEmptyStr; };
      memoryGB = mkOption { type = types.ints.unsigned; };
      cpus = mkOption { type = types.ints.unsigned; };
      vncPort = mkOption { type = types.ints.unsigned; };
      # TODO: network assign fixed ip
    };}));
    default = null;
  };
  config = let inherit (inputs.config.nixos.services) nixvirt; in inputs.lib.mkIf (nixvirt != null)
  {
    virtualisation.libvirt =
    {
      enable = true;
      verbose = true;
      connections."qemu:///system" = let inherit (inputs.topInputs.nixvirt) lib; in
      {
        domains = builtins.map
          (vm:
          {
            definition = 
              let base = lib.domain.templates.linux
              {
                inherit (vm) name;
                inherit (vm.value) uuid;
                memory = { count = vm.value.memoryGB; unit = "GiB"; };
                storage_vol = { pool = "default"; volume = "${vm.value.storage}.qcow2"; };
                install_vol = "${inputs.topInputs.self.src.iso.netboot}";
                virtio_video = false;
              };
              in lib.domain.writeXML (base //
              {
                devices =
                  # remove spicevmc, which needs spice
                  (builtins.removeAttrs base.devices [ "channel" "redirdev" "sound" "audio" ])
                  // {
                    graphics =
                    {
                      type = "vnc";
                      autoport = false;
                      port = vm.value.vncPort;
                      listen.type = "address";
                    };
                  };
                  cpu = base.cpu // { topology = { sockets = 1; dies = 1; cores = vm.value.cpus; threads = 1; };};
                  vcpu = { placement = "static"; count = vm.value.cpus; };
              });
            active = true;
          })
          (inputs.localLib.attrsToList nixvirt);
        networks =
        [{
          definition = lib.network.writeXML (lib.network.templates.bridge
          {
            uuid = "8f403474-f8d6-4fa7-991a-f62f40d51191";
            subnet_byte = 122;
          });
          active = true;
        }];
        pools =
        [{
          definition = lib.pool.writeXML
          {
            name = "default";
            uuid = "6fc75fcc-fb95-48b6-8fa4-0e59b6c1b6c7";
            type = "dir";
            target.path = "/var/lib/libvirt/images";
          };
          active = true;
          volumes =
          [{
            definition = lib.volume.writeXML
            {
              name = "test.qcow2";
              capacity = { count = 20; unit = "GB"; };
            };
          }];
        }];
      };
    };
    nixos.services.kvm = {};
  };
}
