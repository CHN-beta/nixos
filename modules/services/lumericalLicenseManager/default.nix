inputs:
{
  options.nixos.services.lumericalLicenseManager = let inherit (inputs.lib) mkOption types; in mkOption
    { type = types.nullOr (types.submodule {}); default = null; };
  config = let inherit (inputs.config.nixos.services) lumericalLicenseManager;
    in inputs.lib.mkIf (lumericalLicenseManager != null)
  {
    virtualisation.oci-containers.containers.lumericalLicenseManager =
    {
      inherit (inputs.topInputs.self.src.lumerical.licenseManager) image imageFile;
      extraOptions = [ "--network=host" ];
    };
    nixos.services.podman = {};
  };
}
