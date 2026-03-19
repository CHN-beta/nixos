inputs:
{
  options.nixos.system.grub = let inherit (inputs.lib) mkOption types; in mkOption
  {
    type = types.nullOr (types.submodule { options =
    {
      windowsEntries = mkOption { type = types.attrsOf types.nonEmptyStr; default = {}; };
      # "efi" using efi, "efiRemovable" using efi with install grub removable, or dev path like "/dev/sda" using bios
      installDevice = mkOption { type = types.str; default = "efi"; };
    };});
    default = { x86_64 = {}; aarch64 = null; }.${inputs.config.nixos.model.arch};
  };
  config = let inherit (inputs.config.nixos.system) grub; in inputs.localLib.mkConditional (grub != null)
    (inputs.lib.mkMerge
    [
      # general settings
      {
        boot.loader =
        {
          grub = { enable = true; useOSProber = false; };
          timeout = if inputs.config.nixos.model.type == "desktop" then null else 15;
        };
      }
      # grub install
      {
        boot.loader =
        {
          grub =
          {
            device = if builtins.elem grub.installDevice [ "efi" "efiRemovable" ] then "nodev" else grub.installDevice;
            efiSupport = builtins.elem grub.installDevice [ "efi" "efiRemovable" ];
            efiInstallAsRemovable = grub.installDevice == "efiRemovable";
          };
          efi.canTouchEfiVariables = grub.installDevice == "efi";
        };
      }
      # extra grub entries
      {
        boot.loader.grub =
        {
          memtest86.enable = true;
          extraFiles = inputs.lib.mkIf (builtins.elem grub.installDevice [ "efi" "efiRemovable" ])
            { "shell.efi" = "${inputs.pkgs.genericPackages.edk2-uefi-shell}/shell.efi"; };
          extraEntries = inputs.lib.mkMerge (builtins.concatLists
          [
            (builtins.map
              (system:
              ''
                menuentry "${system.value}" {
                  insmod part_gpt
                  insmod fat
                  insmod search_fs_uuid
                  insmod chain
                  search --fs-uuid --set=root ${system.name}
                  chainloader /EFI/Microsoft/Boot/bootmgfw.efi
                }
              '')
              (inputs.lib.attrsToList grub.windowsEntries))
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
              (
                inputs.lib.optionalString (builtins.elem grub.installDevice [ "efi" "efiRemovable" ])
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
          ]);
        };
      }
    ])
    { boot.loader.grub.enable = false; };
}
