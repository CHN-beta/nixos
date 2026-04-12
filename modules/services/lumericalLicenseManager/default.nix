{ lib, config, flakeInputs, pkgs, ... }:
{
  options.nixos.services.lumericalLicenseManager = lib.mkOption
  {
    type = lib.types.nullOr (lib.types.submodule { options =
    {
      macAddress = lib.mkOption { type = lib.types.str; };
      autoStart = lib.mkOption { type = lib.types.bool; default = true; };
    };});
    default = null;
  };
  config = let inherit (config.nixos.services) lumericalLicenseManager; in lib.mkIf (lumericalLicenseManager != null)
  {
    virtualisation.oci-containers.containers.lumericalLicenseManager =
    {
      inherit (flakeInputs.self.src.lumerical.licenseManager) image imageFile;
      extraOptions = [ "--network=host" ];
      volumes =
        let
          macAddress = builtins.replaceStrings [ ":" ] [ "" ] lumericalLicenseManager.macAddress;
          license = pkgs.localPkgs.lumerical.license.override { inherit macAddress; };
        in [ "${license}:/home/ansys_inc/shared_files/licensing/license_files/ansyslmd.lic" ];
    };
    nixos.services.podman = {};
    systemd.services.podman-lumericalLicenseManager.wantedBy =
      lib.mkIf (!lumericalLicenseManager.autoStart) (lib.mkForce []);
  };
}
