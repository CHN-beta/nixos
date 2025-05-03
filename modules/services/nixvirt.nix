inputs:
{
  options.nixos.services.nixvirt = let inherit (inputs.lib) mkOption types; in mkOption
  {
    type = types.nullOr (types.attrsOf (types.submodule (submoduleInputs: { options =
      let
        hash = builtins.hashString "sha256" submoduleInputs.config._module.args.name;
        createString = separator: parts: builtins.concatStringsSep separator
          (builtins.map (p: builtins.substring (builtins.head p) (builtins.elemAt p 1) hash) parts);
      in
      {
        uuid = mkOption
        {
          type = types.nonEmptyStr;
          default = createString "-" [ [ 0 8 ] [ 8 4 ] [ 12 4 ] [ 16 4 ] [ 20 12 ] ];
        };
        storage = mkOption { type = types.nonEmptyStr; default = submoduleInputs.config._module.args.name; };
        memoryGB = mkOption { type = types.ints.unsigned; };
        cpus = mkOption { type = types.ints.unsigned; };
        vnc =
        {
          port = mkOption { type = types.ints.unsigned; default = 15900 + submoduleInputs.config.address; };
          openFirewall = mkOption { type = types.bool; default = true; };
        };
        mac = mkOption
          { type = types.nonEmptyStr; default = "02:${createString ":" [ [ 0 2 ] [ 2 2 ] [ 4 2 ] [ 6 2 ] [ 8 2 ] ]}"; };
        address = mkOption { type = types.ints.unsigned; };
        owner = mkOption { type = types.nonEmptyStr; default = submoduleInputs.config._module.args.name; };
        portForward = rec
        {
          tcp = mkOption
          {
            type = types.listOf (types.submodule { options = rec
              { host = mkOption { type = types.ints.unsigned; }; guest = host; };});
            default = [];
          };
          udp = tcp;
        };
      };})));
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
            (vm: { definition = inputs.config.sops.templates."${vm.name}.xml".path; active = true; })
            (inputs.localLib.attrsToList nixvirt);
          networks =
          [{
            definition =
              let
                base = lib.network.templates.bridge
                  { uuid = "8f403474-f8d6-4fa7-991a-f62f40d51191"; subnet_byte = 122; };
                host = builtins.map
                  (vm: { inherit (vm) mac; ip = "192.168.122.${builtins.toString vm.address}"; })
                  (builtins.attrValues nixvirt);
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
    nixos.services.kvm = {};
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
                memory = { count = vm.value.memoryGB; unit = "GiB"; };
                storage_vol = { pool = "default"; volume = "${vm.value.storage}.qcow2"; };
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
                    port = vm.value.vnc.port;
                    listen.type = "address";
                    passwd = inputs.config.sops.placeholder."nixvirt/${vm.name}";
                  };
                  interface = base.devices.interface // { mac.address = vm.value.mac; };
                };
                cpu = base.cpu // { topology = { sockets = 1; dies = 1; cores = vm.value.cpus; threads = 1; };};
                vcpu = { placement = "static"; count = vm.value.cpus; };
            });
        })
        (inputs.localLib.attrsToList nixvirt));
      secrets = builtins.listToAttrs (builtins.map
        (vm: { name = "nixvirt/${vm}"; value = {}; }) (builtins.attrNames nixvirt));
      placeholder = builtins.listToAttrs (builtins.map
        (vm: { name = "nixvirt/${vm}"; value = builtins.hashString "sha256" "nixvirt/${vm}"; })
        (builtins.attrNames nixvirt));
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
              let vms = builtins.groupBy (vm: vm.value.owner) (inputs.localLib.attrsToList nixvirt);
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
    networking.firewall.allowedTCPPorts = builtins.map (vm: vm.vnc.port)
      (builtins.filter (vm: vm.vnc.openFirewall) (builtins.attrValues nixvirt));
    systemd.services.nixvirt-forward =
      let
        nftRules = builtins.concatLists (builtins.concatLists (builtins.map
          (vm: builtins.map
            (protocol: builtins.map
              (port: "${protocol} dport ${builtins.toString port.host} "
                + "counter dnat ip to 192.168.122.${builtins.toString vm.address}:${builtins.toString port.guest}")
              vm.portForward.${protocol})
            [ "tcp" "udp" ])
          (builtins.attrValues nixvirt)));
        nft = "${inputs.pkgs.nftables}/bin/nft";
        nftConfigFile = inputs.pkgs.writeText "nixvirt.nft"
        ''
          table inet nixvirt {
            chain prerouting {
              type nat hook prerouting priority dstnat; policy accept;
              ${builtins.concatStringsSep "\n" nftRules}
            }
          }
        '';
        # libvirt use iptables to reject forward-input packages.
        # packages accept in nftables but reject in iptables will finally be rejected.
        # So we need to add a rule in iptables to accept these packages.
        iptables = "${inputs.pkgs.iptables}/bin/iptables";
        iptRules = builtins.concatLists (builtins.concatLists (builtins.map
          (vm: builtins.map
            (protocol: builtins.map
              (port: "${iptables} -t filter -I NIXVIRT_FORWARD -d 192.168.122.${builtins.toString vm.address} "
                + "-p ${protocol} --dport ${builtins.toString port.guest} -j ACCEPT")
              vm.portForward.${protocol})
            [ "tcp" "udp" ])
          (builtins.attrValues nixvirt)));
        start = inputs.pkgs.writeShellScript "nixvirt.start" (builtins.concatStringsSep "\n"
        (
          [
            "${nft} -f ${nftConfigFile}"
            "${iptables} -t filter -N NIXVIRT_FORWARD -w"
            "${iptables} -t filter -I LIBVIRT_FWI -j NIXVIRT_FORWARD -w"
          ] ++ iptRules
        ));
        stop = inputs.pkgs.writeShellScript "nixvirt.stop" (builtins.concatStringsSep "\n"
        [
          "${nft} delete table inet nixvirt"
          "${iptables} -t filter -D LIBVIRT_FWI -j NIXVIRT_FORWARD -w"
          "${iptables} -t filter -F NIXVIRT_FORWARD -w"
          "${iptables} -t filter -X NIXVIRT_FORWARD -w"
        ]);
      in
      {
        description = "nixvirt port forward";
        after = [ "nftables.service" "nixvirt.service" ];
        bindsTo= [ "nftables.service" ];
        partOf = [ "nftables.service" "nixvirt.service" ];
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
