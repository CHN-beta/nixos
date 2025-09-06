inputs:
{
  options.nixos.services.lumericalLicenseManager = let inherit (inputs.lib) mkOption types; in mkOption
  {
    type = types.nullOr (types.submodule { options =
    {
      macAddress = mkOption
      {
        type = types.str;
        default = if inputs.config.nixos.system.network != null then "00:01:23:45:67:89" else null;
      };
      createFakeInterface = mkOption { type = types.bool; default = inputs.config.nixos.system.network != null; };
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
    systemd =
    {
      network = inputs.lib.mkIf lumericalLicenseManager.createFakeInterface
      {
        netdevs.ensFakeLumerical.netdevConfig = { Kind = "dummy"; Name = "ens10"; };
        networks."10-ens10" =
          { matchConfig.Name = "ens10"; linkConfig.MACAddress = lumericalLicenseManager.macAddress; };
      };
      services.podman-lumericalLicenseManager.wantedBy =
        inputs.lib.mkIf (!lumericalLicenseManager.autoStart) (inputs.lib.mkForce []);
    };
  };
}
