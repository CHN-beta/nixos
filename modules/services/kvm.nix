inputs:
{
  options.nixos.services.kvm = let inherit (inputs.lib) mkOption types; in mkOption
  {
    type = types.nullOr (types.submodule { options =
    {
      autoSuspend = mkOption { type = types.listOf types.nonEmptyStr; default = []; };
    };});
    default = null;
  };
  config = let inherit (inputs.config.nixos.services) kvm; in inputs.lib.mkIf (kvm != null)
  {
    nix.settings.system-features = [ "kvm" ];
    boot =
    {
      kernelModules = 
        let modules = { intel = [ "kvm-intel" ]; amd = []; };
        in builtins.concatLists (builtins.map (cpu: modules.${cpu}) inputs.config.nixos.hardware.cpus);
      extraModprobeConfig =
        let configs = { intel = "options kvm_intel nested=1"; amd = ""; };
        in builtins.concatStringsSep "\n" (builtins.map (cpu: configs.${cpu}) inputs.config.nixos.hardware.cpus);
    };
    virtualisation =
    {
      libvirtd =
      {
        enable = true;
        qemu.runAsRoot = false;
        onBoot = "ignore";
        onShutdown = "shutdown";
        shutdownTimeout = 30;
        parallelShutdown = 4;
        qemu =
        {
          ovmf.packages = with inputs.pkgs; [ OVMF.fd pkgsCross.aarch64-multiplatform.OVMF.fd ];
          swtpm.enable = true;
        };
      };
      spiceUSBRedirection.enable = true;
    };
    environment.systemPackages = with inputs.pkgs; [ qemu_full win-spice guestfs-tools virt-manager ];
    systemd =
    {
      services =
        let
          virsh = "${inputs.pkgs.libvirt}/bin/virsh";
          hibernate = inputs.pkgs.writeShellScript "libvirt-hibernate"
          ''
            if [ "$(LANG=C ${virsh} domstate $1)" = 'running' ]
            then
              if ${virsh} dompmsuspend "$1" disk
              then
                echo "Waiting for $1 to suspend"
                while ! [ "$(LANG=C ${virsh} domstate $1)" = 'shut off' ]
                do
                  sleep 1
                done
                echo "$1 suspended"
                touch "/tmp/libvirt.$1.suspended"
              else
                echo "Failed to suspend $1"
              fi
            fi
          '';
          resume = inputs.pkgs.writeShellScript "libvirt-resume"
          ''
            if [ "$(LANG=C ${virsh} domstate $1)" = 'shut off' ] && [ -f "/tmp/libvirt.$1.suspended" ]
            then
              if ${virsh} start "$1"
              then
                echo "Waiting for $1 to resume"
                while ! [ "$(LANG=C ${virsh} domstate $1)" = 'running' ]
                do
                  sleep 1
                done
                echo "$1 resumed"
                rm "/tmp/libvirt.$1.suspended"
              else
                echo "Failed to resume $1"
              fi
            fi
          '';
          makeHibernate = machine:
          {
            name = "libvirt-hibernate-${machine}";
            value =
            {
              description = "libvirt hibernate ${machine}";
              wantedBy = [ "systemd-hibernate.service" "systemd-suspend.service" ];
              before = [ "systemd-hibernate.service" "systemd-suspend.service" ];
              serviceConfig = { Type = "oneshot"; ExecStart = "${hibernate} ${machine}"; };
            };
          };
          makeResume = machine:
          {
            name = "libvirt-resume-${machine}";
            value =
            {
              description = "libvirt resume ${machine}";
              wantedBy = [ "systemd-hibernate.service" "systemd-suspend.service" ];
              after = [ "systemd-hibernate.service" "systemd-suspend.service" ];
              serviceConfig = { Type = "oneshot"; ExecStart = "${resume} ${machine}"; };
            };
          };
          makeServices = serviceFunction: builtins.map serviceFunction kvm.autoSuspend;
        in builtins.listToAttrs (makeServices makeHibernate ++ makeServices makeResume);
      mounts =
      [{
        what = "${inputs.topInputs.nixvirt.lib.guest-install.virtio-win.iso}";
        where = "/var/lib/libvirt/images/virtio-win.iso";
        options = "bind";
        wantedBy = [ "local-fs.target" ];
      }];
    };
  };
}
