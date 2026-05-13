{ lib, config, self, pkgs, ... }:
{
  options.nixos.services.lumericalLicenseManager = lib.mkOption
  {
    type = lib.types.nullOr (lib.types.submodule { options =
    {
      macAddress = lib.mkOption { type = lib.types.str; };
    };});
    default = null;
  };
  config = let inherit (config.nixos.services) lumericalLicenseManager; in lib.mkIf (lumericalLicenseManager != null)
  {
    virtualisation.oci-containers.containers.lumericalLicenseManager =
    {
      inherit (self.src.lumerical.licenseManager) image imageFile;
      extraOptions = [ "--network=host" ];
      volumes =
        let
          macAddress = builtins.replaceStrings [ ":" ] [ "" ] lumericalLicenseManager.macAddress;
          license = pkgs.localPkgs.lumerical.license.override { inherit macAddress; };
        in [ "${license}:/home/ansys_inc/shared_files/licensing/license_files/ansyslmd.lic" ];
    };
    nixos.services.podman = {};
  };
}
