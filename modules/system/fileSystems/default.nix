inputs:
{
  options.nixos.system.fileSystems = let inherit (inputs.lib) mkOption types; in
  {
    mount =
    {
      # device = mountPoint;
      vfat = mkOption { type = types.attrsOf types.nonEmptyStr; default = {}; };
      # device.subvol = mountPoint;
      btrfs = mkOption { type = types.attrsOf (types.attrsOf types.nonEmptyStr); default = {}; };
    };
    decrypt =
    {
      auto = mkOption
      {
        type = types.attrsOf (types.submodule
        {
          options =
          {
            mapper = mkOption { type = types.nonEmptyStr; };
            ssd = mkOption { type = types.bool; default = false; };
            before = mkOption { type = types.nullOr (types.listOf types.nonEmptyStr); default = null; };
          };
        });
        default = {};
      };
      manual =
      {
        enable = mkOption { type = types.bool; default = false; };
        devices = mkOption
        {
          type = types.attrsOf (types.submodule
          {
            options =
            {
              mapper = mkOption { type = types.nonEmptyStr; };
              ssd = mkOption { type = types.bool; default = false; };
            };
          });
          default = {};
        };
        keyFile = mkOption
          { type = types.path; default = ./. + "/${inputs.config.nixos.system.networking.hostname}.key"; };
        delayedMount = mkOption { type = types.listOf types.nonEmptyStr; default = []; };
      };
    };
    # generate using: sudo mdadm --examine --scan
    mdadm = mkOption { type = types.nullOr types.lines; default = null; };
    swap = mkOption { type = types.listOf types.nonEmptyStr; default = []; };
    # device or { device, offset }
    resume = mkOption
    {
      type = types.nullOr (types.oneOf [ types.nonEmptyStr (types.submodule { options =
        { device = mkOption { type = types.nonEmptyStr; }; offset = mkOption { type = types.ints.unsigned; }; };
      })]);
      default = null;
    };
    rollingRootfs = mkOption
    {
      type = types.nullOr (types.submodule { options =
      {
        device = mkOption { type = types.nonEmptyStr; default = inputs.config.fileSystems."/".device; };
        path = mkOption { type = types.nonEmptyStr; default = "/nix/rootfs"; };
        waitDevices = mkOption { type = types.listOf types.nonEmptyStr; default = []; };
      };});
      default = null;
    };
  };
  config =
    let
      inherit (builtins) listToAttrs map concatLists concatStringsSep;
      inherit (inputs.lib) mkMerge mkIf;
      inherit (inputs.localLib) attrsToList;
      inherit (inputs.config.nixos.system) fileSystems;
    in mkMerge
    [
      # mount.vfat
      {
        fileSystems = listToAttrs (map
          (device:
          {
            name = device.value;
            value = { device = device.name; fsType = "vfat"; neededForBoot = true; options = [ "noatime" ]; };
          })
          (attrsToList fileSystems.mount.vfat));
      }
      # mount.btrfs
      # Disable CoW for VM image and database: sudo chattr +C images
      # resize btrfs:
      # sudo btrfs filesystem resize -50G /nix
      # sudo cryptsetup status root
      # sudo cryptsetup -b 3787456512 resize root
      # sudo cfdisk /dev/nvme1n1p3
      {
        fileSystems = listToAttrs (concatLists (map
          (
            device: map
              (
                subvol:
                {
                  name = subvol.value;
                  value =
                  {
                    device = device.name;
                    fsType = "btrfs";
                    # zstd:15 cause sound stuttering
                    # test on e20dae7d8b317f95718b5f4175bd4246c09735de mathematica ~15G
                    # zstd:15 5m33s 7.16G
                    # zstd:8 54s 7.32G
                    # zstd:3 17s 7.52G
                    options = [ "compress-force=zstd" "subvol=${subvol.name}" "acl" "noatime" ];
                    neededForBoot = true;
                  };
                }
              )
              (attrsToList device.value)
          )
          (attrsToList fileSystems.mount.btrfs)));
      }
      # decrypt.auto
      (
        mkIf (fileSystems.decrypt.auto != null)
        {
          boot.initrd =
          {
            luks.devices = (listToAttrs (map
              (
                device:
                {
                  name = device.value.mapper;
                  value =
                  {
                    device = device.name;
                    allowDiscards = device.value.ssd;
                    bypassWorkqueues = device.value.ssd;
                    crypttabExtraOpts = [ "fido2-device=auto" "x-initrd.attach" ];
                  };
                }
              )
              (attrsToList fileSystems.decrypt.auto)));
            systemd.services =
              let
                createService = device:
                {
                  name = "systemd-cryptsetup@${device.value.mapper}";
                  value =
                  {
                    before = map (device: "systemd-cryptsetup@${device}.service") device.value.before;
                    overrideStrategy = "asDropin";
                  };
                };
              in
                listToAttrs (map createService
                  (builtins.filter (device: device.value.before != null) (attrsToList fileSystems.decrypt.auto)));
          };
        }
      )
      # decrypt.manual
      (
        mkIf (fileSystems.decrypt.manual.enable)
        {
          boot.initrd =
          {
            luks.forceLuksSupportInInitrd = true;
            systemd =
            {
              extraBin =
              {
                cryptsetup = "${inputs.pkgs.cryptsetup.bin}/bin/cryptsetup";
                usbip = "${inputs.config.boot.kernelPackages.usbip}/bin/usbip";
                sed = "${inputs.pkgs.gnused}/bin/sed";
                awk = "${inputs.pkgs.gawk}/bin/awk";
                decrypt = inputs.pkgs.writeShellScript "decrypt"
                ''
                  modprobe vhci-hcd
                  busid=$(usbip list -r 127.0.0.1 | head -n4 | tail -n1 | awk '{print $1}' | sed 's/://')
                  usbip attach -r 127.0.0.1 -b $busid
                  ${concatStringsSep "\n" (map
                    (device: ''systemd-cryptsetup attach ${device.value.mapper} ${device.name} "" fido2-device=auto''
                      + (if device.value.ssd then ",discard" else ""))
                    (attrsToList fileSystems.decrypt.manual.devices))}
                '';
              };
              services.wait-manual-decrypt =
              {
                wantedBy = [ "initrd-root-fs.target" ];
                before = [ "roll-rootfs.service" ];
                unitConfig.DefaultDependencies = false;
                serviceConfig.Type = "oneshot";
                script = concatStringsSep "\n" (map
                  (device: "while [ ! -e /dev/mapper/${device.value.mapper} ]; do sleep 1; done")
                  (attrsToList fileSystems.decrypt.manual.devices));
              };
            };
          };
          fileSystems = listToAttrs (map
            (mount: { name = mount; value.options = [ "x-systemd.device-timeout=48h" ]; })
            fileSystems.decrypt.manual.delayedMount);
        }
      )
      # mdadm
      (
        mkIf (fileSystems.mdadm != null)
          { boot.initrd.services.swraid = { enable = true; mdadmConf = fileSystems.mdadm; }; }
      )
      # swap
      { swapDevices = map (device: { device = device; }) fileSystems.swap; }
      # resume
      (
        mkIf (fileSystems.resume != null) { boot =
        (
          if builtins.typeOf fileSystems.resume == "string" then
            { resumeDevice = fileSystems.resume; }
          else
          {
            resumeDevice = fileSystems.resume.device;
            kernelModules = [ "resume_offset=${builtins.toString fileSystems.resume.offset}" ];
          }
        );}
      )
      # rollingRootfs
      (
        mkIf (fileSystems.rollingRootfs != null)
        {
          boot.initrd.systemd =
          {
            extraBin =
            {
              grep = "${inputs.pkgs.gnugrep}/bin/grep";
              awk = "${inputs.pkgs.gawk}/bin/awk";
              chattr = "${inputs.pkgs.e2fsprogs}/bin/chattr";
              lsmod = "${inputs.pkgs.kmod}/bin/lsmod";
            };
            services.roll-rootfs =
            {
              wantedBy = [ "initrd.target" ];
              after = [ "cryptsetup.target" "systemd-hibernate-resume.service" ];
              before = [ "local-fs-pre.target" "sysroot.mount" ];
              unitConfig.DefaultDependencies = false;
              serviceConfig.Type = "oneshot";
              script =
                let
                  inherit (fileSystems.rollingRootfs) device path waitDevices;
                  waitDevice = concatStringsSep "\n" (builtins.map
                    (device: "while ! [ -e ${device} ]; do sleep 1; done") (waitDevices ++ [ device ]));
                in
                ''
                  while ! lsmod | grep -q btrfs; do sleep 1; done
                  ${waitDevice}
                  mount ${device} /mnt -m
                  if [ -f /mnt${path}/current/.timestamp ]
                  then
                    timestamp=$(cat /mnt${path}/current/.timestamp)
                    subvolid=$(btrfs subvolume show /mnt${path}/current | grep 'Subvolume ID:' | awk '{print $NF}')
                    mv /mnt${path}/current /mnt${path}/$timestamp-$subvolid
                    btrfs property set -ts /mnt${path}/$timestamp-$subvolid ro true
                  fi
                  btrfs subvolume create /mnt${path}/current
                  chattr +C /mnt${path}/current
                  echo $(date '+%Y%m%d%H%M%S') > /mnt${path}/current/.timestamp
                  umount /mnt
                '';
            };
          };
        }
      )
    ];
}


