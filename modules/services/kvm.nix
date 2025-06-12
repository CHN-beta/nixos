inputs:
{
  options.nixos.services.kvm = let inherit (inputs.lib) mkOption types; in mkOption
  {
    type = types.nullOr (types.submodule { options =
    {
      nodatacow = mkOption { type = types.bool; default = false; };
      aarch64 = mkOption { type = types.bool; default = false; };
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
          ovmf.packages = with inputs.pkgs;
            ([ OVMF.fd ] ++ inputs.lib.optionals kvm.aarch64 [ pkgsCross.aarch64-multiplatform.OVMF.fd ]);
          swtpm.enable = true;
        };
      };
      spiceUSBRedirection.enable = true;
    };
    environment =
    {
      persistence."/nix/nodatacow".directories = inputs.lib.mkIf kvm.nodatacow
        [{ directory = "/var/lib/libvirt/images"; mode = "0711"; }];
      systemPackages = with inputs.pkgs;
        [ win-spice guestfs-tools virt-manager virt-viewer inputs.config.virtualisation.qemu.package ];
    };
    systemd.mounts =
    [{
      what = "${inputs.topInputs.nixvirt.lib.guest-install.virtio-win.iso}";
      where = "/var/lib/libvirt/images/virtio-win.iso";
      options = "bind";
      wantedBy = [ "local-fs.target" ];
    }];
    hardware.ksm.enable = true;
  };
}
