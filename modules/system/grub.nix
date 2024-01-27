inputs:
{
  options.nixos.system.grub = let inherit (inputs.lib) mkOption types; in
  {
    timeout = mkOption { type = types.int; default = 5; };
    windowsEntries = mkOption { type = types.attrsOf types.nonEmptyStr; default = {}; };
    # "efi" using efi, "efiRemovable" using efi with install grub removable, or dev path like "/dev/sda" using bios
    installDevice = mkOption { type = types.str; };
  };
  config =
    let
      inherit (inputs.lib) mkIf;
      inherit (inputs.localLib) mkConditional attrsToList stripeTabs;
      inherit (inputs.config.nixos.system) grub;
      inherit (builtins) concatStringsSep map;
    in { boot.loader =
    {
      timeout = grub.timeout;
      grub =
      {
        enable = true;
        useOSProber = false;
        extraEntries = concatStringsSep "\n" (map
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
          (attrsToList grub.windowsEntries));
        device =
          if grub.installDevice == "efi" || grub.installDevice == "efiRemovable" then "nodev"
          else grub.installDevice;
        efiSupport = grub.installDevice == "efi" || grub.installDevice == "efiRemovable";
        efiInstallAsRemovable = grub.installDevice == "efiRemovable";
        memtest86.enable = true;
      };
      efi =
      {
        canTouchEfiVariables = grub.installDevice == "efi";
        efiSysMountPoint =
          if grub.installDevice == "efi" || grub.installDevice == "efiRemovable" then "/boot/efi"
          else inputs.options.boot.loader.efi.efiSysMountPoint.default;
      };
    };};
}
