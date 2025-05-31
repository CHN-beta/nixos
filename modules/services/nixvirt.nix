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
              dedicate = mkOption { type = types.bool; default = false; };
            };
            cpus = mkOption { type = types.ints.unsigned; };
            network =
            {
              mac = mkOption { type = types.nonEmptyStr; default = defaultMac; };
              address = mkOption { type = types.ints.unsigned; };
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
                  (builtins.attrValues nixvirt.instance);
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
          enable = inputs.lib.mkIf (hosts != []) true;
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
            vcpu = { placement = "static"; count = vm.value.cpus; };
            memory =
            {
              count = vm.value.memory.sizeMB;
              unit = "MiB";
              nosharepages = vm.value.memory.dedicate;
              locked = vm.value.memory.dedicate;
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
              topology = { sockets = 1; dies = 1; cores = vm.value.cpus; threads = 1; };
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
                  driver = { name = "qemu"; type = "raw"; cache = "none"; discard = "unmap"; };
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
                source.bridge = "virbr0";
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
    networking.firewall.allowedTCPPorts = builtins.map (vm: vm.network.vnc.port)
      (builtins.filter (vm: vm.network.vnc.openFirewall) (builtins.attrValues nixvirt.instance));
    # TODO: use existing options
    systemd.services.nixvirt-forward =
      let
        nftRules = builtins.concatLists (builtins.concatLists (builtins.map
          (vm: builtins.map
            (protocol: builtins.map
              (port: "${protocol} dport ${builtins.toString port.host} fib daddr type local counter dnat ip to "
                + "192.168.${builtins.toString nixvirt.subnet}.${builtins.toString vm.network.address}"
                + ":${builtins.toString port.guest}")
              vm.network.portForward.${protocol})
            [ "tcp" "udp" ])
          (builtins.attrValues nixvirt.instance)));
        nft = "${inputs.pkgs.nftables}/bin/nft";
        nftConfigFile = inputs.pkgs.writeText "nixvirt.nft"
        ''
          table inet nixvirt {
            chain prerouting {
              type nat hook prerouting priority dstnat; policy accept;
              ${builtins.concatStringsSep "\n" nftRules}
            }
            chain output {
              type nat hook output priority dstnat; policy accept;
              ${builtins.concatStringsSep "\n" nftRules}
            }
          }
        '';
        start = inputs.pkgs.writeShellScript "nixvirt.start" "${nft} -f ${nftConfigFile}";
        stop = inputs.pkgs.writeShellScript "nixvirt.stop" "${nft} delete table inet nixvirt";
      in
      {
        description = "nixvirt port forward";
        after = [ "nftables.service" "nixvirt.service" ];
        serviceConfig =
        {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = start;
          ExecStop = stop;
        };
        wantedBy= [ "multi-user.target" ];
      };
  };
}
