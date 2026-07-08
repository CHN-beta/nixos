{
  lib,
  config,
  pkgs,
  self,
  ...
}:
{
  options.nixos.services.kvm = lib.mkOption {
    type = lib.types.nullOr (
      lib.types.submodule {
        options = {
          nodatacow = lib.mkOption {
            type = lib.types.bool;
            default = false;
          };
        };
      }
    );
    default = null;
  };
  config =
    let
      inherit (config.nixos.services) kvm;
    in
    lib.mkIf (kvm != null) {
      nix.settings.system-features = [ "kvm" ];
      boot =
        let
          inherit (config.nixos.hardware) cpu;
        in
        {
          kernelModules =
            {
              intel = [ "kvm-intel" ];
              amd = [ ];
            }
            .${cpu};
          extraModprobeConfig =
            {
              intel = "options kvm_intel nested=1";
              amd = "";
            }
            .${cpu};
        };
      virtualisation = {
        libvirtd = {
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
      environment = {
        persistence."/nix/nodatacow".directories = lib.mkIf kvm.nodatacow [
          {
            directory = "/var/lib/libvirt/images";
            mode = "0711";
          }
        ];
        systemPackages = with pkgs; [
          win-spice
          guestfs-tools
          virt-manager
          virt-viewer
          config.virtualisation.libvirtd.qemu.package
        ];
      };
      systemd.mounts = [
        {
          what = "${self.inputs.nixvirt.lib.guest-install.virtio-win.iso}";
          where = "/var/lib/libvirt/images/virtio-win.iso";
          options = "bind";
          wantedBy = [ "local-fs.target" ];
        }
      ];
      # libvirt does not setup "allow udp {53, 67}" by default
      # https://github.com/NixOS/nixpkgs/issues/263359#issuecomment-1987267279
      networking.firewall.interfaces."virbr*".allowedUDPPorts = [
        53
        67
      ];
      hardware.ksm.enable = true;
    };
}
