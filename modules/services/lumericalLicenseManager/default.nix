inputs:
{
  options.nixos.services.lumericalLicenseManager = let inherit (inputs.lib) mkOption types; in mkOption
  {
    type = types.nullOr (types.submodule { options =
    {
      macAddress = mkOption { type = types.str; };
      autoStart = mkOption { type = types.bool; default = true; };
    };});
    default = null;
  };
  config = let inherit (inputs.config.nixos.services) lumericalLicenseManager;
    in inputs.lib.mkIf (lumericalLicenseManager != null)
  {
    virtualisation.oci-containers.containers.lumericalLicenseManager =
    {
      inherit (inputs.topInputs.self.src.lumerical.licenseManager) image imageFile;
      extraOptions = [ "--network=host" ];
      volumes =
        let
          macAddress = builtins.replaceStrings [ ":" ] [ "" ] lumericalLicenseManager.macAddress;
          license = inputs.pkgs.localPackages.lumerical.license.override { inherit macAddress; };
        in [ "${license}:/home/ansys_inc/shared_files/licensing/license_files/ansyslmd.lic" ];
    };
    nixos.services.podman = {};
    systemd.services.podman-lumericalLicenseManager.wantedBy =
      inputs.lib.mkIf (!lumericalLicenseManager.autoStart) (inputs.lib.mkForce []);
  };
}
