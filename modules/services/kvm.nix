inputs:
{
  options.nixos.services.kvm = let inherit (inputs.lib) mkOption types; in mkOption
  {
    type = types.nullOr (types.submodule { options =
    {
      nodatacow = mkOption { type = types.bool; default = false; };
    };});
    default = null;
  };
  config = let inherit (inputs.config.nixos.services) kvm; in inputs.lib.mkIf (kvm != null)
  {
    nix.settings.system-features = [ "kvm" ];
    boot = let inherit (inputs.config.nixos.hardware) cpu; in
    {
      kernelModules = { intel = [ "kvm-intel" ]; amd = []; }.${cpu};
      extraModprobeConfig = { intel = "options kvm_intel nested=1"; amd = ""; }.${cpu};
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
        qemu.swtpm.enable = true;
      };
      spiceUSBRedirection.enable = true;
    };
    environment =
    {
      persistence."/nix/nodatacow".directories = inputs.lib.mkIf kvm.nodatacow
        [{ directory = "/var/lib/libvirt/images"; mode = "0711"; }];
      systemPackages = with inputs.pkgs;
        [ win-spice guestfs-tools virt-manager virt-viewer inputs.config.virtualisation.libvirtd.qemu.package ];
    };
    systemd.mounts =
    [{
      what = "${inputs.topInputs.nixvirt.lib.guest-install.virtio-win.iso}";
      where = "/var/lib/libvirt/images/virtio-win.iso";
      options = "bind";
      wantedBy = [ "local-fs.target" ];
    }];
    # libvirt does not setup "allow udp {53, 67}" by default
    # https://github.com/NixOS/nixpkgs/issues/263359#issuecomment-1987267279
    networking.firewall.interfaces."virbr*".allowedUDPPorts = [ 53 67 ];
    hardware.ksm.enable = true;
  };
}
