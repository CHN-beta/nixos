inputs:
{
  options.nixos.virtualization = let inherit (inputs.lib) mkOption types; in
  {
    waydroid.enable = mkOption { default = false; type = types.bool; };
    docker.enable = mkOption { default = false; type = types.bool; };
    kvmHost =
    {
      enable = mkOption { default = false; type = types.bool; };
      gui = mkOption { default = false; type = types.bool; };
      autoSuspend = mkOption { type = types.listOf types.string; default = []; };
    };
    kvmGuest.enable = mkOption { default = false; type = types.bool; };
    nspawn = mkOption { type = types.listOf types.nonEmptyStr; default = []; };
  };
  config = let inherit (inputs.lib) mkMerge mkIf; in mkMerge
  [
    # waydroid
    (mkIf inputs.config.nixos.virtualization.waydroid.enable { virtualisation = { waydroid.enable = true; }; })
    # docker
    (
      mkIf inputs.config.nixos.virtualization.docker.enable
      {
        virtualisation.docker =
        {
          # enable = true;
          rootless =
          {
            enable = true;
            setSocketVariable = true;
            daemon.settings = { features.buildkit = true; dns = [ "1.1.1.1" ]; storage-driver = "overlay2"; };
          };
          enableNvidia = builtins.elem "nvidia" inputs.config.nixos.hardware.gpus;
          storageDriver = "overlay2";
        };
        nixos.services.firewall.trustedInterfaces = [ "docker0" ];
      }
    )
    # kvmHost
    (
      mkIf inputs.config.nixos.virtualization.kvmHost.enable
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
            parallelShutdown = 4;
          };
          spiceUSBRedirection.enable = true;
        };
        environment.systemPackages = with inputs.pkgs; [ qemu_full win-spice ] ++
          (if (inputs.config.nixos.virtualization.kvmHost.gui) then [ virt-manager ] else []);
        systemd.services =
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
            makeServices = serviceFunction: builtins.map serviceFunction
              inputs.config.nixos.virtualization.kvmHost.autoSuspend;
          in
            builtins.listToAttrs (makeServices makeHibernate ++ makeServices makeResume);
      }
    )
    # kvmGuest
    (
      mkIf inputs.config.nixos.virtualization.kvmGuest.enable
        { services = { qemuGuest.enable = true; spice-vdagentd.enable = true; xserver.videoDrivers = [ "qxl" ]; }; }
    )
    # nspawn
    {
      systemd.nspawn = builtins.listToAttrs (builtins.map
        (name: { inherit name; value = { execConfig.PrivateUsers = false; networkConfig.VirtualEthernet = false; }; }) 
        inputs.config.nixos.virtualization.nspawn);
    }
  ];
}

# sudo waydroid shell wm set-fix-to-user-rotation enabled
