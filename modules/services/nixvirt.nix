inputs:
{
  options.nixos.services.nixvirt = let inherit (inputs.lib) mkOption types; in mkOption
  {
    type = types.nullOr (types.submodule { options =
    {
      subnet = mkOption { type = types.ints.unsigned; default = 122; };
      instance = mkOption
      {
        type = types.attrsOf (types.submodule (submoduleInputs: { options =
          let
            hash = builtins.hashString "sha256" submoduleInputs.config._module.args.name;
            createString = separator: parts: builtins.concatStringsSep separator
              (builtins.map (p: builtins.substring (builtins.head p) (builtins.elemAt p 1) hash) parts);
            defaultUuid = createString "-" [ [ 0 8 ] [ 8 4 ] [ 12 4 ] [ 16 4 ] [ 20 12 ] ];
            defaultMac = "02:${createString ":" [ [ 0 2 ] [ 2 2 ] [ 4 2 ] [ 6 2 ] [ 8 2 ] ]}";
          in
          {
            uuid = mkOption { type = types.nonEmptyStr; default = defaultUuid; };
            owner = mkOption { type = types.nonEmptyStr; default = submoduleInputs.config._module.args.name; };
            storage =
            {
              name = mkOption { type = types.nonEmptyStr; default = submoduleInputs.config._module.args.name; };
              nodatacow = mkOption { type = types.bool; default = false; };
            };
            memory =
            {
              sizeMB = mkOption { type = types.ints.unsigned; };
              dedicated = mkOption { type = types.bool; default = false; };
            };
            cpu =
            {
              count = mkOption { type = types.ints.unsigned; };
              hyprthread = mkOption { type = types.bool; default = false; };
              set = mkOption { type = types.nullOr (types.nonEmptyListOf types.nonEmptyStr); default = null; };
            };
            network =
            {
              mac = mkOption { type = types.nonEmptyStr; default = defaultMac; };
              address = mkOption { type = types.nullOr types.ints.unsigned; default = null; };
              bridge = mkOption { type = types.bool; default = false; };
              vnc =
              {
                port = mkOption
                  { type = types.ints.unsigned; default = 15900 + submoduleInputs.config.network.address; };
                openFirewall = mkOption { type = types.bool; default = true; };
              };
              portForward = rec
              {
                tcp = mkOption
                {
                  type = types.listOf (types.submodule { options = rec
                    { host = mkOption { type = types.ints.unsigned; }; guest = host; };});
                  default = [];
                };
                udp = tcp;
                web = mkOption { type = types.listOf types.nonEmptyStr; default = []; };
              };
            };
          };}));
        default = {};
      };
    };});
    default = null;
  };
  config = let inherit (inputs.config.nixos.services) nixvirt; in inputs.lib.mkIf (nixvirt != null)
  {
    assertions = builtins.map
      (vm:
      {
        assertion = vm.value.cpu.set != null -> builtins.length vm.value.cpu.set == vm.value.cpu.count;
        message = "nixvirt.instance.${vm.name}.cpu.set must have the same length as cpu.count";
      })
      (inputs.localLib.attrsToList nixvirt.instance);
    virtualisation =
    {
      libvirt =
      {
        enable = true;
        verbose = true;
        connections."qemu:///system" = let inherit (inputs.topInputs.nixvirt) lib; in
        {
          domains = builtins.map
            (vm:
            {
              definition = inputs.config.sops.templates."nixvirt/${vm.name}.xml".path;
              active = true;
              restart = false;
            })
            (inputs.localLib.attrsToList nixvirt.instance);
          networks =
          [{
            definition =
              let
                base = lib.network.templates.bridge
                  { uuid = "8f403474-f8d6-4fa7-991a-f62f40d51191"; subnet_byte = nixvirt.subnet; };
                host = builtins.map
                  (vm:
                  {
                    inherit (vm.network) mac;
                    ip = "192.168.${builtins.toString nixvirt.subnet}.${builtins.toString vm.network.address}";
                  })
                  (builtins.filter (vm: vm.network.address != null) (builtins.attrValues nixvirt.instance));
              in lib.network.writeXML (base // { ip = base.ip // { dhcp = base.ip.dhcp // { inherit host; }; }; });
            active = true;
            # never restart the network
            # when adding a new VM, add dhcp resolve manually, by:
            # sudo virsh net-update default add ip-dhcp-host "<host mac='' ip='192.168.122.' />" --live
            restart = false;
          }];
          # do not use it to define disk, since it is not declartive
          # create disk manually, by:
          # sudo qemu-img create -f raw /var/lib/libvirt/images/test.img 20G
          # sudo chown qemu-libvirt:qemu-libvirt /var/lib/libvirt/images/test.img
          # sudo chmod 600 /var/lib/libvirt/images/test.img
          pools = [];
        };
      };
      libvirtd.qemu.verbatimConfig =
      ''
        namespaces = []
        vnc_listen = "0.0.0.0"
      '';
    };
    nixos.services =
    {
      nginx =
        let hosts = builtins.concatLists (builtins.map
          (vm: builtins.map
            (domain:
            {
              inherit domain;
              ip = "192.168.${builtins.toString nixvirt.subnet}.${builtins.toString vm.network.address}";
            })
            vm.network.portForward.web)
          (builtins.attrValues nixvirt.instance));
        in
        {
          transparentProxy.map = builtins.listToAttrs (builtins.map
            (host: { name = host.domain; value = "${host.ip}" + ":443"; }) hosts);
          http = builtins.listToAttrs (builtins.map
            (host: { name = host.domain; value.proxy.upstream = "http://${host.ip}" + ":80"; }) hosts);
        };
      kvm = {};
    };
    sops =
    {
      templates = builtins.listToAttrs (builtins.map
        (vm:
        {
          name = "nixvirt/${vm.name}.xml";
          value.content = inputs.topInputs.nixvirt.lib.domain.getXML
          # port from 8bcc23e27a62297254d0e9c87281e650ff777132
          {
            inherit (vm) name;
            inherit (vm.value) uuid;
            type = "kvm";
            vcpu = { placement = "static"; count = vm.value.cpu.count; };
            cputune = inputs.lib.optionalAttrs (vm.value.cpu.set != null)
            {
              vcpupin = builtins.genList
                (cpu: { vcpu = cpu; cpuset = builtins.elemAt vm.value.cpu.set cpu; })
                vm.value.cpu.count;
            };
            memory =
            {
              count = vm.value.memory.sizeMB;
              unit = "MiB";
              nosharepages = vm.value.memory.dedicated;
              locked = vm.value.memory.dedicated;
            };
            os =
            {
              type = "hvm";
              arch = "x86_64";
              machine = "q35";
              bootmenu = { enable = true; timeout = 15000; };
              loader = { readonly = true; type = "pflash"; path = "/run/libvirt/nix-ovmf/OVMF_CODE.fd"; };
              nvram =
              {
                template = "/run/libvirt/nix-ovmf/OVMF_VARS.fd";
                path = "/var/lib/libvirt/qemu/nvram/${vm.name}_VARS.fd";
                templateFormat = "raw";
                format = "raw";
              };
            };
            features = { acpi = {}; apic = {}; };
            cpu =
            {
              mode = "host-passthrough";
              topology =
              {
                sockets = 1;
                dies = 1;
                cores = if vm.value.cpu.hyprthread then vm.value.cpu.count / 2 else vm.value.cpu.count;
                threads = if vm.value.cpu.hyprthread then 2 else 1;
              };
            };
            clock =
            {
              offset = "utc";
              timer =
              [
                { name = "rtc"; tickpolicy = "catchup"; }
                { name = "pit"; tickpolicy = "delay"; }
                { name = "hpet"; present = false; }
              ];
            };
            devices =
            {
              emulator = "${inputs.config.virtualisation.libvirtd.qemu.package}/bin/qemu-system-x86_64";
              disk =
              [
                {
                  type = "file";
                  device = "disk";
                  driver = { name = "qemu"; type = "raw"; cache = "writeback"; discard = "unmap"; };
                  source.file = "${if vm.value.storage.nodatacow then "/nix/nodatacow" else ""}/var/lib/libvirt/images/"
                    + "${vm.value.storage.name}.img";
                  target = { dev = "vda"; bus = "virtio"; };
                  boot.order = 1;
                }
                {
                  type = "file";
                  device = "cdrom";
                  driver = { name = "qemu"; type = "raw"; };
                  source.file = "${inputs.topInputs.self.src.iso.netboot}";
                  target = { dev = "sdc"; bus = "sata"; };
                  readonly = true;
                  boot.order = 10;
                }
              ];
              interface =
              {
                type = "bridge";
                model.type = "virtio";
                mac.address = vm.value.network.mac;
                source.bridge = if vm.value.network.bridge then "nixvirt" else "virbr0";
              };
              input =
              [
                { type = "tablet"; bus = "usb"; }
                { type = "mouse"; bus = "ps2"; }
                { type = "keyboard"; bus = "ps2"; }
              ];
              graphics =
              {
                type = "vnc";
                autoport = false;
                port = vm.value.network.vnc.port;
                listen.type = "address";
                passwd = inputs.config.sops.placeholder."nixvirt/${vm.name}";
              };
              video.model = { type = "qxl"; ram = 65536; vram = 65536; vgamem = 16384; heads = 1; primary = true; };
              rng = { model = "virtio"; backend = { model = "random"; source = /dev/urandom; }; };
            };
          };
        })
        (inputs.localLib.attrsToList nixvirt.instance));
      secrets = builtins.listToAttrs (builtins.map
        (vm: { name = "nixvirt/${vm}"; value = {}; }) (builtins.attrNames nixvirt.instance));
      placeholder = builtins.listToAttrs (builtins.map
        (vm: { name = "nixvirt/${vm}"; value = builtins.hashString "sha256" "nixvirt/${vm}"; })
        (builtins.attrNames nixvirt.instance));
    };
    security.wrappers.vm =
    {
      source =
        let vm = inputs.pkgs.localPackages.vm.override
        {
          vmConfig = inputs.pkgs.writeText "vm.yaml" (builtins.toJSON
          ({
            virsh = "${inputs.pkgs.libvirt}/bin/virsh";
            vm =
              let vms = builtins.groupBy (vm: vm.value.owner) (inputs.localLib.attrsToList nixvirt.instance);
              in builtins.listToAttrs (builtins.map (owner:
              {
                name = builtins.toString inputs.config.nixos.user.uid.${owner.name};
                value = builtins.map (vm: vm.name) owner.value;
              })
              (inputs.localLib.attrsToList vms));
          }));
        };
        in "${vm}/bin/vm";
      program = "vm";
      owner = "root";
      group = "root";
      setuid = true;
    };
    networking =
    {
      firewall.allowedTCPPorts = builtins.map (vm: vm.network.vnc.port)
        (builtins.filter (vm: vm.network.vnc.openFirewall) (builtins.attrValues nixvirt.instance));
      nftables.tables.nixvirt =
      {
        family = "inet";
        content =
          let nftRules = builtins.concatLists (builtins.concatLists (builtins.map
            (vm: builtins.map
              (protocol: builtins.map
                (port: "${protocol} dport ${builtins.toString port.host} fib daddr type local counter dnat ip to "
                  + "192.168.${builtins.toString nixvirt.subnet}.${builtins.toString vm.network.address}"
                  + ":${builtins.toString port.guest}")
                vm.network.portForward.${protocol})
              [ "tcp" "udp" ])
            (builtins.attrValues nixvirt.instance)));
          in
          ''
            chain prerouting {
              type nat hook prerouting priority dstnat; policy accept;
              ${builtins.concatStringsSep "\n" nftRules}
            }
            chain output {
              type nat hook output priority dstnat; policy accept;
              ${builtins.concatStringsSep "\n" nftRules}
            }
          '';
      };
    };
    boot.kernelParams =
      let cpusets = builtins.concatLists (builtins.map
        (vm: vm.cpu.set)
        (builtins.filter (vm: vm.cpu.set != null) (builtins.attrValues nixvirt.instance)));
      in inputs.lib.mkIf (cpusets != []) [ "isolcpus=${builtins.concatStringsSep "," cpusets}" ];
  };
}
