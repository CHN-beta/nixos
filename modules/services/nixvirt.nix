# TODO: fix libvirtd network
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
            hardware =
            {
              storage = mkOption { type = types.nonEmptyStr; default = submoduleInputs.config._module.args.name; };
              memoryMB = mkOption { type = types.ints.unsigned; };
              cpus = mkOption { type = types.ints.unsigned; };
              mac = mkOption { type = types.nonEmptyStr; default = defaultMac; };
            };
            network =
            {
              address = mkOption { type = types.ints.unsigned; };
              vnc =
              {
                port = mkOption { type = types.ints.unsigned; default = 15900 + submoduleInputs.config.network.address; };
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
            (vm: { definition = inputs.config.sops.templates."${vm.name}.xml".path; active = true; restart = false; })
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
                    inherit (vm.hardware) mac;
                    ip = "192.168.${builtins.toString nixvirt.subnet}.${builtins.toString vm.network.address}";
                  })
                  (builtins.attrValues nixvirt.instance);
              in lib.network.writeXML (base // { ip = base.ip // { dhcp = base.ip.dhcp // { inherit host; }; }; });
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
            # do not define image here, since it still needs to be created manually
          }];
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
          name = "${vm.name}.xml";
          value.content =
            let
              inherit (inputs.topInputs.nixvirt) lib;
              base = lib.domain.templates.linux
              {
                inherit (vm) name;
                inherit (vm.value) uuid;
                memory = { count = vm.value.hardware.memoryMB; unit = "MiB"; };
                storage_vol = { pool = "default"; volume = "${vm.value.hardware.storage}.img"; };
                install_vol = "${inputs.topInputs.self.src.iso.netboot}";
                virtio_video = false;
              };
            in lib.domain.getXML (base //
            {
              devices =
                # remove spicevmc, which needs spice
                (builtins.removeAttrs base.devices [ "channel" "redirdev" "sound" "audio" ])
                // {
                  graphics =
                  {
                    type = "vnc";
                    autoport = false;
                    port = vm.value.network.vnc.port;
                    listen.type = "address";
                    passwd = inputs.config.sops.placeholder."nixvirt/${vm.name}";
                  };
                  interface = base.devices.interface // { mac.address = vm.value.hardware.mac; };
                  disk = builtins.map (disk: disk // { driver = disk.driver // { type = "raw"; }; }) base.devices.disk;
                };
              cpu = base.cpu // { topology = { sockets = 1; dies = 1; cores = vm.value.hardware.cpus; threads = 1; };};
              vcpu = { placement = "static"; count = vm.value.hardware.cpus; };
              os = (builtins.removeAttrs base.os [ "boot" ]) //
              {
                loader = { readonly = true; type = "pflash"; path = "/run/libvirt/nix-ovmf/OVMF_CODE.fd"; };
                nvram =
                {
                  template = "/run/libvirt/nix-ovmf/OVMF_VARS.fd";
                  path = "/var/lib/libvirt/qemu/nvram/${vm.name}_VARS.fd";
                  templateFormat = "raw";
                  format = "raw";
                };
              };
            });
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
