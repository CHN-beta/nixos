{
  lib,
  config,
  pkgs,
  ...
}:
{
  options.nixos.system.grub = lib.mkOption {
    type = lib.types.nullOr (
      lib.types.submodule {
        options = {
          windowsEntries = lib.mkOption {
            type = lib.types.attrsOf lib.types.nonEmptyStr;
            default = { };
          };
          # "efi" using efi, "efiRemovable" using efi with install grub removable, dev path like "/dev/sda" using bios, or "hybrid:/dev/sda" using hybrid
          installDevice = lib.mkOption {
            type = lib.types.str;
            default = "efi";
          };
        };
      }
    );
    default =
      {
        x86_64 = { };
        aarch64 = null;
      }
      .${config.nixos.model.arch};
  };
  config =
    let
      inherit (config.nixos.system) grub;
    in
    lib.mkConditional (grub != null) (lib.mkMerge [
      # general settings
      {
        boot.loader = {
          grub = {
            enable = true;
            useOSProber = false;
          };
          timeout = if config.nixos.model.variant == "desktop" then null else 15;
        };
      }
      # grub install
      {
        boot.loader = {
          grub = {
            device =
              if
                builtins.elem grub.installDevice [
                  "efi"
                  "efiRemovable"
                ]
              then
                "nodev"
              else if lib.strings.hasPrefix "hybrid:" grub.installDevice then
                lib.strings.removePrefix "hybrid:" grub.installDevice
              else
                grub.installDevice;
            efiSupport =
              builtins.elem grub.installDevice [
                "efi"
                "efiRemovable"
              ]
              || lib.strings.hasPrefix "hybrid:" grub.installDevice;
            efiInstallAsRemovable =
              grub.installDevice == "efiRemovable" || lib.strings.hasPrefix "hybrid:" grub.installDevice;
          };
          efi.canTouchEfiVariables = grub.installDevice == "efi";
        };
      }
      # extra grub entries
      {
        boot.loader.grub = {
          memtest86.enable = true;
          extraFiles = lib.mkIf (
            builtins.elem grub.installDevice [
              "efi"
              "efiRemovable"
            ]
            || lib.strings.hasPrefix "hybrid:" grub.installDevice
          ) { "shell.efi" = "${pkgs.genericPkgs.edk2-uefi-shell}/shell.efi"; };
          extraEntries = lib.mkMerge (
            builtins.concatLists [
              (builtins.map (system: ''
                menuentry "${system.value}" {
                  insmod part_gpt
                  insmod fat
                  insmod search_fs_uuid
                  insmod chain
                  search --fs-uuid --set=root ${system.name}
                  chainloader /EFI/Microsoft/Boot/bootmgfw.efi
                }
              '') (lib.attrsToList grub.windowsEntries))
              [
                ''
                  menuentry "System shutdown" {
                    echo "System shutting down..."
                    halt
                  }
                  menuentry "System restart" {
                    echo "System rebooting..."
                    reboot
                  }
                ''
                (lib.optionalString
                  (
                    builtins.elem grub.installDevice [
                      "efi"
                      "efiRemovable"
                    ]
                    || lib.strings.hasPrefix "hybrid:" grub.installDevice
                  )
                  ''
                    menuentry 'UEFI Firmware Settings' --id 'uefi-firmware' {
                      fwsetup
                    }
                    menuentry "UEFI Shell" {
                      insmod fat
                      insmod chain
                      chainloader @bootRoot@/shell.efi
                    }
                  ''
                )
              ]
            ]
          );
        };
      }
    ]) { boot.loader.grub.enable = false; };
}
