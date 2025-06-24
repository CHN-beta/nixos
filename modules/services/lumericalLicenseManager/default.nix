inputs:
{
  options.nixos.services.lumericalLicenseManager = let inherit (inputs.lib) mkOption types; in mkOption
    { type = types.nullOr (types.submodule {}); default = null; };
  config = let inherit (inputs.config.nixos.services) lumericalLicenseManager;
    in inputs.lib.mkIf (lumericalLicenseManager != null)
  {
    virtualisation.oci-containers.containers.lumericalLicenseManager =
    {
      image = "lumericallicensemanager:2023r1";
      imageFile = inputs.topInputs.self.src.lumerical.licenseManagerImage;
      ports = [ "127.0.0.1:1084:1084/tcp" "127.0.0.1:1055:1055/tcp" "127.0.0.1:2325:2325/tcp" ];
      extraOptions = [ "--mac-address=00:01:23:45:67:89" ];
    };
    nixos.services.docker = {};
  };
}
