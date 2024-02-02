inputs:
{
  options.nixos.system.grub = let inherit (inputs.lib) mkOption types; in
  {
    timeout = mkOption { type = types.int; default = 5; };
    windowsEntries = mkOption { type = types.attrsOf types.nonEmptyStr; default = {}; };
    # "efi" using efi, "efiRemovable" using efi with install grub removable, or dev path like "/dev/sda" using bios
    installDevice = mkOption { type = types.str; };
  };
  config = let inherit (inputs.config.nixos.system) grub; in inputs.lib.mkMerge
  [
    # general settings
    { boot.loader.grub = { enable = true; useOSProber = false; }; }
    # grub timeout
    { boot.loader.timeout = grub.timeout; }
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
        efi =
        {
          canTouchEfiVariables = grub.installDevice == "efi";
          efiSysMountPoint = inputs.lib.mkIf (builtins.elem grub.installDevice [ "efi" "efiRemovable" ]) "/boot/efi";
        };
      };
    }
    # extra grub entries
    {
      boot.loader.grub =
      {
        memtest86.enable = true;
        extraFiles = inputs.lib.mkIf (builtins.elem grub.installDevice [ "efi" "efiRemovable" ])
          { "shell.efi" = "${inputs.pkgs.edk2-uefi-shell}/shell.efi"; };
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
            (inputs.localLib.attrsToList grub.windowsEntries))
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
                  chainloader /shell.efi
                }
              ''
            )
          ]
        ]);
      };
    }
  ];
}
